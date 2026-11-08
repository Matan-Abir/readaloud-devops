# Alert rule tests

`promtool test rules` feeds made-up metric series to the alert rules from the
Helm chart and checks that the right alert fires (or doesn't) at the right time.
CI renders the chart for staging, extracts the rules into `rules.yaml`, and runs:

```sh
promtool check rules rules.yaml
promtool test rules rules-test.yaml
```
