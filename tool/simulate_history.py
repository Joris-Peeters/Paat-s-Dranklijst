#!/usr/bin/env python3
"""Fills a Paat's Dranklijst database with a few years of simulated history.

For testing statistics, history and balances against realistic data: users in
Leiding / Aspi's / Oud-leiding, five items, and every consumption, top-up and
adjustment of about three Chiro years. It replaces all users, items, groups and
transactions. Settings live in shared preferences and are left alone.

    python3 tool/simulate_history.py                    # the Linux dev database
    python3 tool/simulate_history.py --out sim.sqlite   # a copy, left untouched source

A copy can be put in the app's backup folder on any device and restored from
settings. The source must be a database the app created: this script only fills
the schema, it never writes it. Close the app first.

Standard library only. The same --seed always gives the same history.
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import sqlite3
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

TZ = ZoneInfo('Europe/Brussels')
DAY_START = timedelta(hours=7)  # the logical day runs 07:00 -> 07:00
DEFAULT_DB = (
    Path.home()
    / '.local/share/xyz.jpsystems.paats_dranklijst/paats_dranklijst.sqlite'
)
DEFAULT_START = date(2023, 9, 1)
DEFAULT_SEED = 1001

MON, TUE, WED, THU, FRI, SAT, SUN = range(7)

# seedColorPalette in lib/widgets/palette_picker.dart, as ARGB.
PINK = 0xFFE91E63
DEEP_ORANGE = 0xFFFF5722
ORANGE = 0xFFFF9800
AMBER = 0xFFFFC107
LIME = 0xFFCDDC39
GREEN = 0xFF4CAF50
TEAL = 0xFF009688
CYAN = 0xFF00BCD4
LIGHT_BLUE = 0xFF03A9F4
INDIGO = 0xFF3F51B5
DEEP_PURPLE = 0xFF673AB7
PURPLE = 0xFF9C27B0

L, A, O = 'leiding', 'aspi', 'oud'
USER_GROUPS = [(L, 'Leiding', '⛺'), (A, "Aspi's", '🔥'), (O, 'Oud-leiding', '🎓')]

# --- Catalogue -------------------------------------------------------------


@dataclass
class ItemDef:
    key: str
    name: str
    emoji: str
    group: str
    prices: list[tuple[date, int]]  # (since, minor units), oldest first
    snack: bool = False
    id: int = 0

    def price_on(self, day: date) -> int:
        return [p for since, p in self.prices if since <= day][-1]


ITEM_GROUPS = [('drinks', 'Dranken', '🧃'), ('snacks', 'Snacks', '🥨')]
ITEMS = [
    ItemDef('pils', 'Pils', '🍺', 'drinks',
            [(date.min, 120), (date(2025, 9, 1), 150)]),
    ItemDef('fris', 'Frisdrank', '🥤', 'drinks',
            [(date.min, 100), (date(2025, 9, 1), 120)]),
    ItemDef('speciaal', 'Speciaalbier', '🍻', 'drinks', [(date.min, 250)]),
    ItemDef('chips', 'Chips', '🍿', 'snacks', [(date.min, 100)], snack=True),
    ItemDef('snoep', 'Snoep', '🍬', 'snacks', [(date.min, 80)], snack=True),
]
ITEM = {i.key: i for i in ITEMS}

# Item preference per role, before the user's own taste. Aspi's are 16-17:
# beer is legal, strong beer is not.
ROLE_ITEMS = {
    L: {'pils': 6.0, 'fris': 2.5, 'speciaal': 1.2, 'chips': 0.8, 'snoep': 0.4},
    A: {'pils': 1.2, 'fris': 5.0, 'speciaal': 0.0, 'chips': 1.3, 'snoep': 1.1},
    O: {'pils': 6.0, 'fris': 1.3, 'speciaal': 2.2, 'chips': 0.7, 'snoep': 0.2},
}

# --- Users -----------------------------------------------------------------

S23, S24, S25, S26 = (date(y, 9, 1) for y in (2023, 2024, 2025, 2026))


@dataclass
class UserDef:
    name: str
    emoji: str
    color: int
    roles: list[tuple[date, str]]  # (since, role); the first is when they joined
    birthday: tuple[int, int]  # (month, day)
    presence: float = 1.0  # x the role's chance of turning up
    thirst: float = 1.0  # x the role's items per visit
    beer: float = 1.0  # x Pils and Speciaalbier; 0 never drinks alcohol
    snacks: float = 1.0
    works: bool = False  # past school: exam periods don't apply
    pays_below: int = -1500  # tops up once the balance is under this
    pays: tuple[int, ...] = (10, 20)  # presets in whole euro; 0 pays exactly
    pay_chance: float = 0.6  # per visit, once under the threshold
    left: date | None = None  # settles to zero the day before, then archived
    id: int = 0

    def role_on(self, day: date) -> str | None:
        if day < self.roles[0][0] or (self.left and day >= self.left):
            return None
        return [r for since, r in self.roles if since <= day][-1]

    @property
    def current_role(self) -> str:
        return self.roles[-1][1]


USERS = [
    # Leiding today.
    UserDef('Jonas', '🦁', ORANGE, [(S23, L)], (3, 14), presence=1.15,
            thirst=1.5, pays_below=-3000, pays=(50,)),
    UserDef('Lotte', '🦊', PINK, [(S23, L)], (11, 2), presence=1.1,
            thirst=0.85, snacks=1.6, pays_below=-500, pays=(20,), pay_chance=0.9),
    UserDef('Wout', '🐻', DEEP_ORANGE, [(S23, L)], (6, 21), presence=0.9,
            thirst=1.8, works=True, pays_below=-4000, pays=(0,), pay_chance=0.25),
    UserDef('Sien', '🦉', TEAL, [(S23, L)], (1, 28), thirst=0.8, beer=0.0,
            snacks=1.3, pays_below=500, pays=(20,), pay_chance=0.95),
    UserDef('Robbe', '🐸', GREEN, [(S23, L)], (8, 9), presence=0.7, thirst=1.1),
    UserDef('Marie', '🦄', PURPLE, [(S23, A), (S24, L)], (4, 30),
            thirst=0.9, pays=(10,), pay_chance=0.8),
    UserDef('Arne', '🐙', INDIGO, [(S23, A), (S24, L)], (10, 5),
            presence=0.95, thirst=1.3, pays_below=-2000, pays=(20, 50)),
    UserDef('Seppe', '🐧', LIGHT_BLUE, [(S23, A), (S25, L)], (12, 12),
            presence=0.85, thirst=1.2),
    UserDef('Noor', '🐝', AMBER, [(S24, A), (S25, L)], (5, 17),
            presence=1.05, thirst=0.8, snacks=1.4, pays=(10,)),
    # Aspi's today, and one who stopped instead of becoming leiding.
    UserDef('Emma', '🐢', LIME, [(S25, A)], (2, 8), pays_below=-500, pays=(5, 10)),
    UserDef('Kobe', '🦖', CYAN, [(S25, A)], (9, 22), presence=1.1, thirst=1.3,
            snacks=1.5, pays_below=-800, pays=(5, 10)),
    UserDef('Lien', '🐳', DEEP_PURPLE, [(S25, A)], (7, 3), presence=0.8,
            thirst=0.7, beer=0.2, pays_below=-500, pays=(5,)),
    UserDef('Milan', '🐯', PINK, [(S26, A)], (1, 11), thirst=1.2,
            pays_below=-500, pays=(10,)),
    UserDef('Jade', '🐨', TEAL, [(S26, A)], (6, 4), presence=0.9,
            pays_below=-500, pays=(5, 10)),
    UserDef('Ruben', '🐵', GREEN, [(S23, A)], (3, 3), presence=0.75,
            snacks=1.8, pays_below=-600, pays=(5, 10), left=date(2025, 8, 25)),
    # Oud-leiding today.
    UserDef('Pieter', '🦩', INDIGO, [(S23, O)], (2, 19), presence=1.4,
            thirst=1.6, works=True, pays_below=-2500, pays=(50,)),
    UserDef('Hanne', '🐞', ORANGE, [(S23, L), (S25, O)], (9, 9), thirst=0.9,
            snacks=1.2, pays=(20,), pay_chance=0.8),
    UserDef('Bram', '🐹', DEEP_ORANGE, [(S23, L), (S24, O)], (12, 28),
            presence=0.9, thirst=1.7, works=True, pays_below=-3500, pays=(0,),
            pay_chance=0.35),
    UserDef('Tibo', '🦔', LIGHT_BLUE, [(S23, L), (S24, O)], (8, 30),
            presence=0.6, thirst=1.1, works=True, pays=(20,)),
    UserDef('Elien', '🐼', PURPLE, [(S23, O)], (5, 5), presence=0.8,
            works=True, pays=(20,), left=date(2026, 3, 15)),
]

# --- Occasions -------------------------------------------------------------


@dataclass
class Table:
    start: float  # hours after the day's midnight; past 24 is after midnight
    end: float
    presence: dict[str, float]
    thirst: dict[str, float]  # mean items per visit
    beer: float = 1.0
    speciaal: float = 1.0
    rounds: float = 0.0  # mean rounds of Pils fetched for several people
    activity: bool = False  # a Sunday activity: no beer before 17:00


TABLES = {
    'sunday': Table(13.5, 19.5, {L: .85, A: .80, O: .04},
                    {L: 2.4, A: 1.8, O: 2.5}, speciaal=0.5, activity=True),
    'startdag': Table(13.5, 20.5, {L: .97, A: .95, O: .30},
                      {L: 3.2, A: 1.9, O: 3.2}, speciaal=0.7, rounds=0.8,
                      activity=True),
    'saturday': Table(19.5, 27.0, {L: .40, A: .05, O: .12},
                      {L: 4.2, A: 1.8, O: 4.0}, speciaal=1.4, rounds=0.6),
    'friday': Table(20.0, 26.0, {L: .30, A: .03, O: .08},
                    {L: 3.4, A: 1.5, O: 3.5}, rounds=0.4),
    'meeting': Table(20.0, 23.5, {L: .80, A: 0, O: 0}, {L: 2.0, A: 0, O: 0}),
    'weekday': Table(19.0, 23.0, {L: .04, A: 0, O: .01}, {L: 1.8, A: 0, O: 2.0}),
    'summer': Table(19.0, 26.0, {L: .22, A: .03, O: .10},
                    {L: 3.8, A: 1.5, O: 3.8}, rounds=0.5),
    'prep': Table(18.5, 23.5, {L: .45, A: 0, O: .03}, {L: 2.5, A: 0, O: 2.5}),
    'party': Table(20.0, 28.0, {L: .92, A: .55, O: .55},
                   {L: 6.0, A: 2.5, O: 5.5}, beer=1.3, speciaal=1.8, rounds=1.6),
    'birthday': Table(20.0, 27.5, {L: .75, A: .08, O: .35},
                      {L: 5.0, A: 2.0, O: 4.5}, beer=1.2, speciaal=1.5,
                      rounds=1.3),
    'nye': Table(21.0, 29.0, {L: .45, A: .10, O: .35},
                 {L: 6.5, A: 2.0, O: 6.0}, beer=1.2, speciaal=2.0, rounds=1.8),
    'spaghetti': Table(17.0, 23.5, {L: .95, A: .70, O: .45},
                       {L: 3.5, A: 2.0, O: 3.0}, rounds=0.8),
}
EVENTS = {'startdag', 'party', 'birthday', 'nye', 'spaghetti'}


@dataclass
class Occasion:
    kind: str  # a TABLES key, or 'away'
    label: str | None = None
    mult: float = 1.0
    host: UserDef | None = None


def easter(year: int) -> date:
    """Anonymous Gregorian algorithm."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = divmod(b, 4)
    g = (8 * b + 13) // 25
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month, day = divmod(h + l - 7 * m + 114, 31)
    return date(year, month, day + 1)


def nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    """The [n]th [weekday] of the month, or the last one for n = -1."""
    if n > 0:
        first = date(year, month, 1)
        return first + timedelta(days=(weekday - first.weekday()) % 7 + 7 * (n - 1))
    last = date(year + month // 12, month % 12 + 1, 1) - timedelta(days=1)
    return last - timedelta(days=(last.weekday() - weekday) % 7)


def next_weekday(day: date, weekday: int) -> date:
    """The first [weekday] strictly after [day]."""
    return day + timedelta(days=(weekday - day.weekday() - 1) % 7 + 1)


def days(first: date, last: date):
    while first <= last:
        yield first
        first += timedelta(days=1)


def chiro_year(day: date) -> int:
    """A Chiro year starts on 1 September and is named after that year."""
    return day.year if day.month >= 9 else day.year - 1


class Calendar:
    """What happens at the lokaal on each day of the simulation."""

    def __init__(self, first: date, last: date, rng: random.Random):
        self.special: dict[date, Occasion] = {}
        self.holidays: dict[date, str] = {}
        self.school_free: set[date] = set()
        self.season: dict[int, tuple[date, date]] = {}  # first and last Sunday activity
        for y in range(chiro_year(first), chiro_year(last) + 1):
            self._year(y, rng)
        self.noise = {d: rng.lognormvariate(0, 0.15) for d in days(first, last)}
        self.hot = {
            d for d in days(first, last)
            if d.month in (6, 7, 8) and rng.random() < (0.12 if d.month == 6 else 0.2)
        }

    def _put(self, day: date, occasion: Occasion) -> None:
        self.special.setdefault(day, occasion)

    def _away(self, first: date, last: date, label: str) -> None:
        for d in days(first, last):
            self._put(d, Occasion('away', label))

    def _year(self, y: int, rng: random.Random) -> None:
        e = easter(y + 1)
        for d, name in [
            (date(y, 11, 1), 'Allerheiligen'), (date(y, 11, 11), 'Wapenstilstand'),
            (date(y, 12, 25), 'Kerstmis'), (date(y + 1, 1, 1), 'Nieuwjaar'),
            (e + timedelta(days=1), 'Paasmaandag'), (date(y + 1, 5, 1), 'Dag van de Arbeid'),
            (e + timedelta(days=39), 'O.L.H. Hemelvaart'), (e + timedelta(days=50), 'Pinkstermaandag'),
            (date(y + 1, 7, 21), 'Nationale feestdag'), (date(y + 1, 8, 15), 'O.L.V. Hemelvaart'),
        ]:
            self.holidays[d] = name

        # School holidays: autumn, Christmas, krokus and Easter.
        autumn = nth_weekday(y, 11, SUN, 1)
        ash_wednesday = e - timedelta(days=46)
        for first, last in [
            (autumn - timedelta(days=13), autumn),
            (date(y, 12, 22), date(y + 1, 1, 4)),
            (ash_wednesday - timedelta(days=2), ash_wednesday + timedelta(days=4)),
            (e - timedelta(days=6), e + timedelta(days=8)),
        ]:
            self.school_free.update(days(first, last))

        # Away first, so nothing else lands on those days.
        self._away(date(y + 1, 7, 18), date(y + 1, 7, 31), 'Bivak')
        self._away(date(y, 12, 24), date(y, 12, 25), 'Kerstmis')
        for sat in (nth_weekday(y, 11, SAT, 3), e + timedelta(days=13)):
            self._away(sat - timedelta(days=1), sat + timedelta(days=1), 'Leidingsweekend')

        startdag = nth_weekday(y, 9, SUN, -1)
        self.season[y] = (startdag, nth_weekday(y + 1, 6, SUN, -1))
        self._put(startdag, Occasion('startdag', 'Startdag'))
        self._put(startdag - timedelta(days=1), Occasion('party', 'Startavond', 0.85))
        self._put(nth_weekday(y, 11, SAT, 2), Occasion('spaghetti', 'Spaghettiavond'))
        christmas_party = date(y, 12, 21) - timedelta(days=(date(y, 12, 21).weekday() - SAT) % 7)
        self._put(christmas_party, Occasion('party', 'Kerstfeestje', 0.75))
        self._put(date(y, 12, 31), Occasion('nye', 'Oudejaarsavond'))
        self._put(next_weekday(date(y + 1, 2, 4), SAT), Occasion('party', 'Einde examens', 0.9))
        self._put(nth_weekday(y + 1, 3, SAT, 2), Occasion('party', 'Chirofuif', 1.15))
        self._put(next_weekday(date(y + 1, 7, 3), SAT), Occasion('party', 'Begin zomer', 0.9))
        self._put(date(y + 1, 8, 1), Occasion('prep', 'Uitpakken bivak', 1.8))

        for user in USERS:
            month, dom = user.birthday
            birthday = date(y if month >= 9 else y + 1, month, dom)
            role = user.role_on(birthday)
            if role == L or (role == O and rng.random() < 0.4):
                sat = birthday + timedelta(days=(SAT - birthday.weekday() + 3) % 7 - 3)
                self._put(sat, Occasion('birthday', f'Verjaardag {user.name}', host=user))

        # A few weekends a year the lokaal is simply closed.
        saturdays = [
            d for d in days(date(y, 10, 1), date(y + 1, 5, 31))
            if d.weekday() == SAT
            and all(d + timedelta(days=k) not in self.special for k in (-1, 0, 1))
        ]
        for sat in rng.sample(saturdays, 2):
            self._away(sat - timedelta(days=1), sat + timedelta(days=1), 'Weekend weg')

    def on(self, day: date) -> Occasion:
        if day in self.special:
            return self.special[day]
        wd = day.weekday()
        if day in self.holidays and wd <= THU:
            return Occasion('weekday', self.holidays[day], 2.0)
        start, end = self.season[chiro_year(day)]
        in_season = start <= day <= end
        tomorrow = day + timedelta(days=1)
        if tomorrow in self.holidays and wd <= THU:
            return Occasion('friday', f'Avond voor {self.holidays[tomorrow]}', 0.8)
        if date(day.year, 7, 5) <= day <= date(day.year, 7, 17) and wd <= FRI:
            return Occasion('prep', 'Bivak voorbereiden')
        if not in_season:
            return Occasion('summer', mult=0.7 if wd <= THU else 1.0)
        if wd == SUN:
            return Occasion('sunday')
        if wd == SAT:
            return Occasion('saturday')
        if wd == FRI:
            return Occasion('friday')
        if wd == WED and day.isocalendar().week % 2:
            return Occasion('meeting')
        return Occasion('weekday', mult=2.5 if day in self.school_free else 1.0)


def exam_factor(user: UserDef, role: str, day: date) -> float:
    """How much an exam period keeps [user] away on [day]."""
    m, d = day.month, day.day
    if role == A:
        if (m == 12 and 5 <= d <= 21) or (m == 6 and 3 <= d <= 27):
            return 0.35
        return 1.0
    if user.works or role == O:
        return 1.0
    if (m == 1 and d >= 3) or (m == 2 and d <= 4):
        return 0.2
    if m == 6 or (m == 7 and d <= 3):
        return 0.25
    if m == 12 and d >= 18:
        return 0.6
    return 1.0


# --- Simulation ------------------------------------------------------------


def epoch(day: date, hours: float) -> int:
    """[hours] of wall-clock time after local midnight of [day]."""
    local = datetime.combine(day, time()) + timedelta(hours=hours)
    return int(local.replace(tzinfo=TZ).timestamp())


def logical_date(ts: int) -> str:
    local = datetime.fromtimestamp(ts, TZ).replace(tzinfo=None)
    return (local - DAY_START).date().isoformat()


def poisson(rng: random.Random, mean: float) -> int:
    limit, k, p = math.exp(-mean), 0, rng.random()
    while p > limit:
        k += 1
        p *= rng.random()
    return k


@dataclass
class Row:
    user: UserDef
    type: str
    amount: int
    created_at: int
    item: ItemDef | None = None
    quantity: int = 1
    unit_price: int | None = None
    note: str | None = None
    voided_at: int | None = None
    voided_note: str | None = None
    confirmed_at: int | None = None
    unpaid: bool = False  # a top-up whose money never comes; voided once noticed
    seq: int = 0


@dataclass
class Visit:
    user: UserDef
    role: str
    arrive: float
    leave: float
    intents: list[list] = field(default_factory=list)  # [hours, item, quantity]


class Simulation:
    def __init__(self, first: date, last: date, seed: int):
        self.rng = random.Random(seed)
        self.first, self.last = first, last
        self.now = int(datetime.now(TZ).timestamp())
        self.calendar = Calendar(first, last, self.rng)
        self.rows: list[Row] = []
        self.balance: dict[str, int] = defaultdict(int)
        self.pending: list[Row] = []
        self.mood: dict[tuple, float] = {}
        self._next_check = first + timedelta(days=self.rng.randint(7, 21))

    def add(self, row: Row) -> Row:
        row.seq = len(self.rows)
        self.rows.append(row)
        if row.voided_at is None:
            self.balance[row.user.name] += row.amount
        if row.type == 'topUp':
            self.pending.append(row)
        return row

    def user_mood(self, user: UserDef, role: str, day: date) -> float:
        """Streaky presence: a month on, then gone for a while. Oud-leiding most."""
        key = (user.name, day.year, day.month)
        if key not in self.mood:
            sigma = {L: 0.25, A: 0.3, O: 0.7}[role]
            self.mood[key] = self.rng.lognormvariate(-sigma * sigma / 2, sigma)
        return self.mood[key]

    def run(self) -> None:
        for day in days(self.first, self.last):
            occasion = self.calendar.on(day)
            if occasion.kind != 'away':
                self.session(day, occasion)
            self.yearly_adjustments(day, occasion)
            for user in USERS:
                if user.left == day + timedelta(days=1):
                    self.settle(user, day)
            if day == self._next_check:
                self.check_top_ups(day)
                self._next_check = day + timedelta(days=self.rng.randint(6, 20))
        self.rows.sort(key=lambda r: (r.created_at, r.seq))

    def session(self, day: date, occasion: Occasion) -> None:
        rng, table = self.rng, TABLES[occasion.kind]
        hot = day in self.calendar.hot
        visits: list[Visit] = []
        for user in USERS:
            role = user.role_on(day)
            if role is None or (table.presence[role] == 0 and user is not occasion.host):
                continue
            p = (table.presence[role] * occasion.mult * user.presence
                 * self.user_mood(user, role, day) * self.calendar.noise[day])
            exams = exam_factor(user, role, day)
            p *= math.sqrt(exams) if occasion.kind in EVENTS else exams
            if user is occasion.host:
                p = 1.0
            if rng.random() >= min(p, 0.97):
                continue
            span = table.end - table.start
            arrive = table.start + span * rng.uniform(0, 0.45)
            leave = arrive + (table.end - arrive) * rng.uniform(0.45, 1.0)
            visits.append(Visit(user, role, arrive, leave))

        for visit in visits:
            user, role = visit.user, visit.role
            mean = (table.thirst[role] * user.thirst * rng.lognormvariate(0, 0.3)
                    * (1.7 if user is occasion.host else 1.0) * (1.12 if hot else 1.0))
            remaining = poisson(rng, mean)
            skew = 2.2 if table.activity else 1.3
            while remaining > 0:
                t = visit.arrive + (visit.leave - visit.arrive) * rng.betavariate(skew, 1)
                item = self.pick_item(user, role, table, t, hot)
                double = 0.12 if occasion.kind in EVENTS else 0.07
                quantity = 2 if remaining > 1 and rng.random() < (0.04 if item.snack else double) else 1
                visit.intents.append([t, item, quantity])
                remaining -= quantity
            # A snack is often tapped in the same basket as a drink.
            drinks = [i for i in visit.intents if not i[1].snack]
            for intent in visit.intents:
                if intent[1].snack and drinks and rng.random() < 0.35:
                    intent[0] = min(drinks, key=lambda d: abs(d[0] - intent[0]))[0]

        for _ in range(poisson(rng, table.rounds)):
            t = rng.uniform(table.start + 1, table.end - 1)
            around = [v for v in visits if v.arrive <= t <= v.leave
                      and any(i[1].key == 'pils' for i in v.intents)]
            if len(around) < 2:
                continue
            for visit in rng.sample(around, rng.randint(2, min(5, len(around)))):
                pils = [i for i in visit.intents if i[1].key == 'pils']
                min(pils, key=lambda i: abs(i[0] - t))[0] = t

        for visit in visits:
            user = visit.user
            if (self.balance[user.name] < user.pays_below
                    and rng.random() < user.pay_chance):
                self.top_up(user, day, visit.arrive + rng.uniform(0, 0.5))
            for hours, item, quantity in visit.intents:
                self.consume(user, day, hours, item, quantity)

    def pick_item(self, user: UserDef, role: str, table: Table, hours: float,
                  hot: bool) -> ItemDef:
        w = dict(ROLE_ITEMS[role])
        w['pils'] *= user.beer * table.beer
        w['speciaal'] *= user.beer * table.speciaal
        w['chips'] *= user.snacks
        w['snoep'] *= user.snacks
        if table.activity and hours < 17:
            w['pils'] *= 0.1
            w['speciaal'] = 0.0
            w['snoep'] *= 2.0
        if hours >= 22:
            w['chips'] *= 2.2
        if hot:
            w['fris'] *= 1.5
            w['pils'] *= 1.15
        keys = list(w)
        return ITEM[self.rng.choices(keys, [w[k] for k in keys])[0]]

    def consume(self, user: UserDef, day: date, hours: float, item: ItemDef,
                quantity: int) -> None:
        ts = epoch(day, hours)
        if ts > self.now:
            return
        price = item.price_on(day)
        row = Row(user, 'consumption', -price * quantity, ts, item, quantity, price)
        delay = self.rng.uniform(600, 5 * 86400)
        if self.rng.random() < 0.008 and ts + delay < self.now:
            row.voided_at = int(ts + delay)
            row.voided_note = self.rng.choice(
                ['Verkeerd getikt', 'Dubbel getikt', 'Verkeerde persoon', None])
        self.add(row)

    def top_up(self, user: UserDef, day: date, hours: float, exact: bool = False) -> None:
        ts = epoch(day, hours)
        if ts > self.now:
            return
        owed = -self.balance[user.name]
        if exact:
            amount = owed
        elif user.pays == (0,):
            amount = max(owed, 500)
        else:
            enough = [p for p in user.pays if p * 100 >= owed]
            amount = (min(enough) if enough else max(user.pays)) * 100
        leaving_soon = user.left and user.left - day < timedelta(days=90)
        unpaid = not exact and not leaving_soon and self.rng.random() < 0.015
        self.add(Row(user, 'topUp', amount, ts, unpaid=unpaid))

    def check_top_ups(self, day: date) -> None:
        """The treasurer ticks off the bank statement every week or three."""
        ts = epoch(day, self.rng.uniform(19, 22))
        if ts > self.now - 10 * 86400:
            return
        still = []
        for row in self.pending:
            if row.created_at > ts - 86400:
                still.append(row)
            elif row.unpaid:
                if row.created_at < ts - 14 * 86400:
                    row.voided_at, row.voided_note = ts, 'Niet betaald'
                    row.unpaid = False
                    self.balance[row.user.name] -= row.amount
                else:
                    still.append(row)
            else:
                row.confirmed_at = ts
        self.pending = still

    def adjust(self, user: UserDef, day: date, amount: int, note: str) -> None:
        ts = epoch(day, self.rng.uniform(21, 23))
        if amount and ts <= self.now:
            self.add(Row(user, 'adjustment', amount, ts, note=note))

    def yearly_adjustments(self, day: date, occasion: Occasion) -> None:
        rng = self.rng
        if occasion.label == 'Chirofuif':
            # The Chiro buys the leiding a drink after the fuif.
            price = ITEM['pils'].price_on(day)
            for user in USERS:
                if user.role_on(day) == L:
                    self.adjust(user, day, 2 * price, 'Rondje van de Chiro na de fuif')
        elif occasion.label == 'Uitpakken bivak':
            # Bivak drinks were kept on paper and get settled afterwards.
            for user in USERS:
                if user.role_on(day) == L:
                    self.adjust(user, day, -rng.randint(8, 25) * 100, 'Drankkaart bivak')
        elif rng.random() < 0.006:
            debtors = [u for u in USERS if u.role_on(day)
                       and self.balance[u.name] < -1500]
            if debtors:
                user = rng.choice(debtors)
                self.adjust(user, day, rng.choice([10, 20]) * 100, 'Cash betaald aan de kassier')

    def settle(self, user: UserDef, day: date) -> None:
        balance = self.balance[user.name]
        if balance < 0:
            self.top_up(user, day, 21.0, exact=True)
        elif balance > 0:
            self.adjust(user, day, -balance, 'Restsaldo terugbetaald bij vertrek')


# --- Database --------------------------------------------------------------


def app_is_running() -> bool:
    """Linux only; elsewhere there is nothing to look in."""
    for comm in Path('/proc').glob('[0-9]*/comm'):
        try:
            if comm.read_text().strip().startswith('paats_dranklij'):
                return True
        except OSError:
            pass
    return False


def write(con: sqlite3.Connection, sim: Simulation) -> None:
    created = epoch(sim.first - timedelta(days=3), 19.0)
    with con:
        for table in ['transactions', 'users', 'items', 'user_groups', 'item_groups']:
            con.execute(f'DELETE FROM {table}')
        con.execute("DELETE FROM sqlite_sequence WHERE name IN "
                    "('transactions', 'users', 'items', 'user_groups', 'item_groups')")

        group_ids = {}
        for order, (key, name, emoji) in enumerate(ITEM_GROUPS):
            group_ids[key] = con.execute(
                'INSERT INTO item_groups (name, emoji, sort_order, created_at) '
                'VALUES (?, ?, ?, ?)', (name, emoji, order, created)).lastrowid
        for order, item in enumerate(ITEMS):
            item.id = con.execute(
                'INSERT INTO items (name, emoji, group_id, price_minor_units, '
                'sort_order, created_at) VALUES (?, ?, ?, ?, ?, ?)',
                (item.name, item.emoji, group_ids[item.group],
                 item.price_on(sim.last), order, created)).lastrowid

        for order, (key, name, emoji) in enumerate(USER_GROUPS):
            group_ids[key] = con.execute(
                'INSERT INTO user_groups (name, emoji, sort_order, created_at) '
                'VALUES (?, ?, ?, ?)', (name, emoji, order, created)).lastrowid
        orders: Counter = Counter()
        for user in USERS:
            role = user.current_role
            joined = max(user.roles[0][0], sim.first)
            archived = epoch(user.left, 12.0) if user.left and user.left <= sim.last else None
            user.id = con.execute(
                'INSERT INTO users (name, avatar_emoji, seed_color_argb, group_id, '
                'sort_order, archived_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
                (user.name, user.emoji, user.color, group_ids[role], orders[role],
                 archived, epoch(joined - timedelta(days=2), 19.5))).lastrowid
            orders[role] += 1

        con.executemany(
            'INSERT INTO transactions (user_id, type, amount_minor_units, quantity, '
            'item_id, item_name_snapshot, item_unit_price_snapshot, note, created_at, '
            'logical_date, voided_at, voided_note, confirmed_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [(r.user.id, r.type, r.amount, r.quantity, r.item and r.item.id,
              r.item and r.item.name, r.unit_price, r.note, r.created_at,
              logical_date(r.created_at), r.voided_at, r.voided_note, r.confirmed_at)
             for r in sim.rows])


def report(con: sqlite3.Connection, sim: Simulation) -> None:
    q = lambda sql, *args: con.execute(sql, args).fetchall()
    print(f'\n{len(sim.rows)} transactions, {sim.first} -> {sim.last}')
    for kind, n, voided in q("SELECT type, COUNT(*), COUNT(voided_at) FROM transactions "
                             "GROUP BY type"):
        print(f'  {kind:<12}{n:>7}   {voided} voided')
    pending = q("SELECT COUNT(*) FROM transactions WHERE type = 'topUp' "
                'AND confirmed_at IS NULL AND voided_at IS NULL')[0][0]
    print(f'  pending top-ups: {pending}')

    live = "type = 'consumption' AND voided_at IS NULL"
    print('\nItems taken')
    for name, n in q(f'SELECT item_name_snapshot, SUM(quantity) FROM transactions '
                     f'WHERE {live} GROUP BY 1 ORDER BY 2 DESC'):
        print(f'  {name:<14}{n:>7}')

    print('\nItems per weekday (logical days)')
    names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    per_wd = Counter()
    for day, n in q(f'SELECT logical_date, SUM(quantity) FROM transactions WHERE {live} '
                    f'GROUP BY 1'):
        per_wd[date.fromisoformat(day).weekday()] += n
    print('  ' + '  '.join(f'{names[i]} {per_wd[i]}' for i in range(7)))

    print('\nItems per month')
    for month, n in q(f'SELECT substr(logical_date, 1, 7), SUM(quantity) FROM transactions '
                      f'WHERE {live} GROUP BY 1'):
        print(f'  {month}  {n:>5}  ' + '#' * (n // 20))

    print('\nUsers')
    for name, group, items, balance, archived in q(
            f'SELECT u.name, g.name, '
            f'(SELECT COALESCE(SUM(quantity), 0) FROM transactions t WHERE t.user_id = u.id AND {live}), '
            f'COALESCE(b.balance_minor_units, 0), u.archived_at IS NOT NULL '
            f'FROM users u JOIN user_groups g ON g.id = u.group_id '
            f'LEFT JOIN user_balances b ON b.user_id = u.id ORDER BY g.sort_order, u.sort_order'):
        flag = '  (archived)' if archived else ''
        print(f'  {name:<8}{group:<13}{items:>6} items  {balance / 100:>9.2f}{flag}')

    print('\nBusiest days')
    for day, n in q(f'SELECT logical_date, SUM(quantity) FROM transactions WHERE {live} '
                    f'GROUP BY 1 ORDER BY 2 DESC LIMIT 5'):
        occasion = sim.calendar.on(date.fromisoformat(day))
        print(f'  {day}  {n:>4}  {occasion.label or occasion.kind}')

    # Checks: these must all come out clean.
    problems = []
    if q('PRAGMA integrity_check')[0][0] != 'ok':
        problems.append('integrity_check failed')
    if q('PRAGMA foreign_key_check'):
        problems.append('foreign_key_check found dangling references')
    def dart_logical_day(ts: int) -> str:
        local = datetime.fromtimestamp(ts, TZ)
        early = local.hour * 60 + local.minute < DAY_START.seconds // 60
        return (local.date() - timedelta(days=1 if early else 0)).isoformat()

    wrong_day = sum(1 for ts, day in q('SELECT created_at, logical_date FROM transactions')
                    if dart_logical_day(ts) != day)
    if wrong_day:
        problems.append(f'{wrong_day} rows with a logical_date off the 07:00 rule')
    for name, expected in sim.balance.items():
        actual = q('SELECT COALESCE(SUM(amount_minor_units), 0) FROM transactions t '
                   'JOIN users u ON u.id = t.user_id WHERE u.name = ? AND voided_at IS NULL',
                   name)[0][0]
        if actual != expected:
            problems.append(f'{name}: balance {actual} in the database, {expected} simulated')
    if q('SELECT COUNT(*) FROM users u JOIN user_balances b ON b.user_id = u.id '
         'WHERE u.archived_at IS NOT NULL AND b.balance_minor_units != 0')[0][0]:
        problems.append('an archived user has a balance')
    print('\nChecks: ' + ('all clean' if not problems else '\n  ' + '\n  '.join(problems)))
    if problems:
        sys.exit(1)


def main() -> None:
    logical_today = (datetime.now(TZ).replace(tzinfo=None) - DAY_START).date()
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--db', type=Path, default=DEFAULT_DB,
                        help=f'database the app created (default: {DEFAULT_DB})')
    parser.add_argument('--out', type=Path,
                        help='write the result here and leave --db untouched')
    parser.add_argument('--seed', type=int, default=DEFAULT_SEED)
    parser.add_argument('--start', type=date.fromisoformat, default=DEFAULT_START)
    parser.add_argument('--end', type=date.fromisoformat,
                        default=logical_today - timedelta(days=1),
                        help='last logical day (default: yesterday)')
    parser.add_argument('--force', action='store_true',
                        help='overwrite --out, or run although the app seems open')
    args = parser.parse_args()

    if not args.db.exists():
        sys.exit(f'{args.db} does not exist. Run the app once to create it.')
    src = sqlite3.connect(args.db)
    tables = {r[0] for r in src.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    if src.execute('PRAGMA user_version').fetchone()[0] < 1 or not {
            'users', 'items', 'transactions', 'user_groups', 'item_groups'} <= tables:
        sys.exit(f'{args.db} is not a database this app created.')

    if args.out:
        if args.out.exists() and not args.force:
            sys.exit(f'{args.out} exists; pass --force to overwrite it.')
        args.out.unlink(missing_ok=True)
        con = sqlite3.connect(args.out)
        src.backup(con)
        src.close()
    else:
        if app_is_running() and not args.force:
            sys.exit('The app seems to be running. Close it first, or pass --force.')
        backup = args.db.with_name(args.db.name + '.pre-sim')
        if backup.exists():
            print(f'Keeping the existing {backup}')
        else:
            src.close()
            shutil.copy2(args.db, backup)
            print(f'Saved the current database to {backup}')
            src = sqlite3.connect(args.db)
        con = src

    con.execute('PRAGMA foreign_keys = ON')
    sim = Simulation(args.start, args.end, args.seed)
    sim.run()
    write(con, sim)
    report(con, sim)
    con.close()
    print(f'\nWrote {args.out or args.db}')


if __name__ == '__main__':
    main()
