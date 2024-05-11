# Allowlist Eligibility Module

A [Hats Protocol](https://github.com/hats-protocol/hats-protocol) eligibility module that uses an allowlist to determine eligibility.

## Overview and Usage

This module sets up a simple allowlist to determine eligibility for a hat. For a given account (i.e., potential hat wearer), the allowlist stores values for that account's eligibility and standing for the hat. The wearer(s) of the `OWNER_HAT` can add or remove accounts from the allowlist. The wearer(s) of the `ARBITRATOR_HAT` can set the standing of accounts.

This module serves as both a "mechanistic" and "humanistic passthrough" eligibility module.

### Mechanistic Functionality

- Wearer(s) of the `OWNER_HAT` can simply add account(s) to the allowlist by calling `addAccount()` or `addAccounts()`.
- Wearer(s) of the `OWNER_HAT` can simply remove account(s) from the allowlist by calling `removeAccount()` or `removeAccounts()`.
- Wearer(s) of the `ARBITRATOR_HAT` can simply set the standing of account(s) by calling `setStandingForAccount()` or `setStandingForAccounts()`.

In each of these cases, Hats Protocol will *pull* eligibility and standing data from the module via `getWearerStatus()`. Hats Protocol will not emit an event with any of these eligibility and resulting wearer changes, so front ends pointing only at Hats Protocol events (or the [subgraph](https://github.com/hats-protocol/subgraph)) will not automatically reclect these changes.

### Humanistic Functionality

- Wearer(s) of the `OWNER_HAT` can manually revoke an account's hat by calling `removeAccountAndBurnHat()`.
- Wearer(s) of the `ARBITRATOR_HAT` can manually put an account in bad standing and burn their hat `setStandingForAccountAndBurnHat()`.

In these cases, the module *pushes* eligibility and standing data to Hats Protocol, causing Hats Protocol to emit event(s) reflecting the eligibility and resulting wearer changes. Front ends pointing at Hats Protocol events (or the subgaph) *will* automatically reflect these changes.

## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To install dependencies, run `forge install`
4. To compile the contracts, run `forge build`
5. To test, run `forge test`

### IR-Optimized Builds

This repo also supports contracts compiled via IR. Since compiling all contracts via IR would slow down testing workflows, we only want to do this for our target contract(s), not anything in this `test` or `script` stack. We accomplish this by pre-compiled the target contract(s) and then loading the pre-compiled artifacts in the test suite.

First, we compile the target contract(s) via IR by running`FOUNDRY_PROFILE=optimized forge build` (ensuring that FOUNDRY_PROFILE is not in our .env file)

Next, ensure that tests are using the `DeployOptimized` script, and run `forge test` as normal.

See the wonderful [Seaport repo](https://github.com/ProjectOpenSea/seaport/blob/main/README.md#foundry-tests) for more details and options for this approach.
