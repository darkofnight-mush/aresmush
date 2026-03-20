---
toc: Chronicles
summary: Roll dice for skill checks and actions in Chronicles of Darkness style games.
aliases:
- dice
- roll dice
---
# Roll

The roll command allows you to roll dice pools for skill checks, combat, and other actions in Chronicles of Darkness style games.

## Basic Usage

`roll <dice pool>`

Where `<dice pool>` is the number of dice to roll, or an expression involving stats and numbers.

### Examples

- `roll 5` - Roll 5 dice.
- `roll Dex + Athletics` - Roll dice equal to your Dexterity + Athletics stats.
- `roll 6 - 2 + 1` - Roll 6 dice minus 2 plus 1 (5 dice total).

## Options

You can add options before the equals sign to modify the roll behavior.

### Dice Mechanics

- `again:X` - Set the explosion threshold (default 10). Dice that roll X or higher explode (roll extra dice).
- `diff:X` - Set the difficulty (default 8). Rolls of X or higher count as successes. Not really used in Chronicles of Darkness, but included for consistency with older WoD style games. 
- `exceptional:X` - Set the exceptional success threshold (default 5). X or more successes is exceptional.
- `rote` - Reroll all failures once (but failures on those rerolls can't be rerolled again).
- `willpower` - Add 3 dice to your pool and spend a point of willpower.

### Examples with Options

- `roll again:9 diff:7 = Dex + Firearms` - Roll with 9-again and difficulty 7.
- `roll rote = Wits + Composure` - Rote action roll.
- `roll willpower = 5` - Roll 5 dice plus 3 willpower dice.

## Comments

Add a comment after a forward slash to describe what you're rolling for.

`roll Dex + Stealth / sneaking past the guard`

## Chance Die

If your dice pool is 0 or negative, you'll roll a chance die instead:
- 10 = Success
- 1 = Dramatic failure
- Anything else = Failure

10's don't explode on a chance die (see CoD p. 69)
## Output

The roll shows:
- Your dice pool breakdown
- Any options used as Dice Tricks
- Individual rolls (color-coded: red for failures, green for successes, cyan for explosions)
- Total successes
- Exceptional success note if applicable

## Stats

You can use character stats in your dice pool expressions. Unknown stats will be treated as 0 and listed as warnings.