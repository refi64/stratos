# stratos.inject

This contains code that is "injected" into the captures page by Stratos.

## Response interception

Stadia's RPC format is rather...messy. In order to avoid extra pain, the
"easiest" thing to do is simply intercept its own XMLHttpRequests and grab the
captures responses from there.
