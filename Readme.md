=== Mon Jun 22 15:51:12 MDT 2015 ===

Project Notes
-------------

Instructions for Running:
./notifycancelholds.sh

Testing:
Collect all the holds for a givien catalog key that matches no visible items and holds greater than 0, or:
```
echo "$catKey" | selhold -iC -j"ACTIVE" -oIUt | selitem -iI -oSB | seluser -iU -oBS
```
Should look like:
```
21221023778928|25531974|20160324|T|ACTIVE|31221070724872  |
21221023917641|25578424|20160331|T|ACTIVE|480052-113001   |
21221023760744|25611406|20160405|T|ACTIVE|480052-113001   |
21221023759837|25615325|20160405|T|ACTIVE|480052-113001   |
...
```
Next gather all the holds for the users that have holds on the title and save all their holds.
```
cat /tmp/holdbot_cancel_holds_on_title_selection.00.20160923.080145 | seluser -iB | selhold -iU -jACTIVE -oIUKptj | selitem -iI -oSB | seluser -iU -oBS >existing_holds_480052.lst
```
When you compare the 2 lists from above the line count from existing_holds_480052.lst should be n - lines from list 1.

Product Description:
Bash shell script written by Andrew Nisbet for Edmonton Public Library, distributable by the enclosed license.

Repository Information:
This product is under version control using Git.

Dependencies:
[pipe.pl](https://github.com/anisbet/pipe)
[diff.pl](https://github.com/anisbet/diff)
[holdbot.pl](https://github.com/Edmonton-Public-Library/holdbot)

Known Issues:
None
