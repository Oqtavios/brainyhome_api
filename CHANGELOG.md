## 0.12.11

- Added custom user agent and http client
- Updated dependencies and minimum Dart version

## 0.12.10

- Added support for applicationName/tokenName in firstConnect
- Updated dependencies

## 0.12.9

- Updated dependencies

## 0.12.8

- Added dontOverwriteCacheIfHashIsIdentical parameter

## 0.12.7+1

- Fixed dataHashCode being changed when retrieving data from cache because cached value was changed (by accessing Response.data members)

- ## 0.12.7

- Now making shallow copies when putting combined members into cache
- Added dataHashCode parameter to the Response. It should remain the same as long data isn't changed

## 0.12.6

- Added combined requests support

## 0.12.5

- During connect, if connection to either local and remote URIs cannot be established, default address will be set to remote and reconnection timeout will be short

## 0.12.4

- Fixed uri not initializing if it had protocol in it
- Fixed test expecting token query parameter but using api with header authorization

## 0.12.3

- Fixed continuous waiting for in-progress cache item if it was failed and cacheErrors is false

## 0.12.2

- Fixed http errors not respecting cacheErrors parameter

## 0.12.1

- Added inProgress cache status to decrease multiple calls of one type if there's already a call in progress

## 0.12.0

- Added null-safety support (BREAKING CHANGE)

## 0.11.5

- Fixed incorrect token check delay mechanism in tokenIsActivated method
- Prepared the package for publishing

## 0.11.4

- Updated http package

## 0.11.3

- Added appendCache method for adding currently non-existent items to cache

## 0.11.2

- Added port autocompletion if port is not provided

## 0.11.1

- Cleaned firstConnect method 
- Fixed empty remote URI handling as existing

## 0.11.0

- Split request timeout into local and remote (BREAKING CHANGE)

## 0.10.5

- Added content type changer for requests with binary data

## 0.10.4

- Added https enforcing option

## 0.10.3

- Fixed remote URI checking bug

## 0.10.2

- Added option to change connection enforcements by calling connect method with corresponding parameters. Now you cannot initialize API with both forceLocal and forceRemote set to true.

## 0.10.1

- Fixed API initialization error when remote URI is null

## 0.10.0

- Added built-in support for remote API
- Breaking change! connect() now checks connectivity and determines whether to use local or remote address
- firstConnect() replaces old connect()
- Added options to enforce remote/local APIs

## 0.9.1

- Added header authentication support and options to control and override it

## 0.9.0

- Initial testing version, created by Oqtavios
