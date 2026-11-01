"""The flags of the guides' language list, simplified so they stay clear at the size of a chip.

Start:  imported by scripts/pictures.py, not started on its own
Needs:  nothing beyond Python
Each flag is drawn in a 30 × 20 grid (3:2), which pictures.py rounds and frames like the tiles.
A language names the flag of the country it is most at home in, such as English the American one.
"""

import math

# MARK: Pieces


def star(center_x: float, center_y: float, radius: float, color: str) -> str:
    """A five-pointed star, one point up."""
    points = []
    for corner in range(10):
        reach = radius if corner % 2 == 0 else radius * 0.4
        angle = math.radians(-90 + corner * 36)
        x, y = center_x + reach * math.cos(angle), center_y + reach * math.sin(angle)
        points.append(f"{x:.2f},{y:.2f}")
    return f'<polygon points="{" ".join(points)}" fill="{color}"/>'


def field(color: str) -> str:
    return f'<rect width="30" height="20" fill="{color}"/>'


def stripes(*colors: str, across: bool = True) -> str:
    """Equal stripes from the top down, or from the left when across is False."""
    size = (20 if across else 30) / len(colors)
    box = ('y="{:.2f}" width="30" height="{:.2f}"' if across
           else 'x="{:.2f}" width="{:.2f}" height="20"')
    return "".join(f'<rect {box.format(number * size, size)} fill="{color}"/>'
                   for number, color in enumerate(colors))


def nordic(background: str, *crosses: tuple[str, float]) -> str:
    """A cross set toward the flagpole; each cross is a color and its width, widest first."""
    shapes = [field(background)]
    for color, width in crosses:
        shapes.append(
            f'<rect x="{10.5 - width / 2:g}" width="{width:g}" height="20" fill="{color}"/>'
            f'<rect y="{10 - width / 2:g}" width="30" height="{width:g}" fill="{color}"/>')
    return "".join(shapes)


def stars_of_china() -> str:
    small = ((10, 2), (12, 4), (12, 7), (10, 9))
    return star(5, 5, 3, "#FFDE00") + "".join(star(x, y, 1, "#FFDE00") for x, y in small)


def stars_of_america() -> str:
    return "".join(
        f'<circle cx="{1.5 + column * 2.25:g}" cy="{1.4 + row * 2:g}" r=".45" fill="#FFFFFF"/>'
        for row in range(5) for column in range(5))


def trigrams() -> str:
    """The four black bars of Korea's flag, one leaning into each corner."""
    return "".join(
        f'<rect x="{x}" y="{y}" width="4" height="1" rx=".3" fill="#000000" '
        f'transform="rotate({angle} {x + 2} {y + .5})"/>'
        for x, y, angle in ((3, 3.5, -34), (23, 3.5, 34), (3, 15.5, 34), (23, 15.5, -34)))


# MARK: Flags

FLAGS = {
    "CN": field("#DE2910") + stars_of_china(),
    "TW": field("#FE0000") + '<rect width="15" height="10" fill="#000095"/>'
          '<circle cx="7.5" cy="5" r="2.6" fill="#FFFFFF"/>',
    "CZ": stripes("#FFFFFF", "#D7141A") + '<polygon points="0,0 15,10 0,20" fill="#11457E"/>',
    "DK": nordic("#C8102E", ("#FFFFFF", 3)),
    "NL": stripes("#AE1C28", "#FFFFFF", "#21468B"),
    "US": stripes(*["#B22234", "#FFFFFF"] * 6, "#B22234")
          + '<rect width="12" height="10.77" fill="#3C3B6E"/>' + stars_of_america(),
    "FI": nordic("#FFFFFF", ("#002F6C", 4)),
    "FR": stripes("#0055A4", "#FFFFFF", "#EF4135", across=False),
    "DE": stripes("#000000", "#DD0000", "#FFCE00"),
    "GR": stripes(*["#0D5EAF", "#FFFFFF"] * 4, "#0D5EAF")
          + '<rect width="11.1" height="11.1" fill="#0D5EAF"/>'
          + '<rect x="4.44" width="2.22" height="11.1" fill="#FFFFFF"/>'
          + '<rect y="4.44" width="11.1" height="2.22" fill="#FFFFFF"/>',
    "IN": stripes("#FF9933", "#FFFFFF", "#138808")
          + '<circle cx="15" cy="10" r="2.6" fill="none" stroke="#000080" stroke-width=".8"/>'
          + '<circle cx="15" cy="10" r=".7" fill="#000080"/>',
    "HU": stripes("#CE2939", "#FFFFFF", "#477050"),
    "ID": stripes("#FF0000", "#FFFFFF"),
    "IT": stripes("#009246", "#FFFFFF", "#CE2B37", across=False),
    "JP": field("#FFFFFF") + '<circle cx="15" cy="10" r="6" fill="#BC002D"/>',
    "KR": field("#FFFFFF")
          + '<path d="M10 10a5 5 0 0 1 10 0z" fill="#CD2E3A"/>'
          + '<path d="M10 10a5 5 0 0 0 10 0z" fill="#0047A0"/>'
          + '<circle cx="12.5" cy="10" r="2.5" fill="#CD2E3A"/>'
          + '<circle cx="17.5" cy="10" r="2.5" fill="#0047A0"/>' + trigrams(),
    "NO": nordic("#BA0C2F", ("#FFFFFF", 5), ("#00205B", 2.5)),
    "PL": stripes("#FFFFFF", "#DC143C"),
    "BR": field("#009C3B") + '<polygon points="15,2.5 27,10 15,17.5 3,10" fill="#FFDF00"/>'
          '<circle cx="15" cy="10" r="4.2" fill="#002776"/>',
    "PT": field("#FF0000") + '<rect width="12" height="20" fill="#006600"/>'
          '<circle cx="12" cy="10" r="3.6" fill="#FFE900"/>'
          '<rect x="10.4" y="8" width="3.2" height="4" rx="1" fill="#FFFFFF" stroke="#FF0000" '
          'stroke-width=".6"/>',
    "RO": stripes("#002B7F", "#FCD116", "#CE1126", across=False),
    "RU": stripes("#FFFFFF", "#0039A6", "#D52B1E"),
    "ES": field("#AA151B") + '<rect y="5" width="30" height="10" fill="#F1BF00"/>',
    "SE": nordic("#006AA7", ("#FECC00", 3)),
    "TH": stripes("#A51931", "#FFFFFF", "#2D2A4A", "#2D2A4A", "#FFFFFF", "#A51931"),
    "TR": field("#E30A17") + '<circle cx="11" cy="10" r="5" fill="#FFFFFF"/>'
          '<circle cx="12.3" cy="10" r="4" fill="#E30A17"/>' + star(17, 10, 2.2, "#FFFFFF"),
    "UA": stripes("#0057B7", "#FFD700"),
    "VN": field("#DA251D") + star(15, 10.5, 5.5, "#FFFF00"),
}
