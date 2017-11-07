# Mac sandbox

## Purpose

The purpose is to make sandboxes in macOS, which allow us to install anything, destory anything and try new things freely like Docker containers.

## How to use

### Step 1. Make `myroot` directory by `makeup.rb`

```bash
cd <this repo>
ruby makeup.rb myroot
```

### Step 2. Enter the `myroot`

```bash
sudo chroot ./myroot
```

That's all !

## Available/unavailable commands

### Host environment

```
macOS Sierra
Version 10.12.6
```

### Primitives

##### WORK!
- [x] `cd`
- [x] `pwd`
- [x] `ls`
- [x] `bash`
- [x] `sh`
- [x] `bash`
- [x] `mkdir`
- [x] `rm`
- [x] `rmdir`
- [x] `touch`
- [x] `cat`
- [x] `grep`
- [x] `which`

#### NOT-WORK :(

- [] `ps` - Killed: 9
- [] `sudo` - Killed: 9



### Networking

#### WORK!

- [x] `nslookup`
- [x] `dig`


#### NOT-WORK :(

- [] `curl` - cann't solve google.com
- [] `ping` - Killed: 9
- [] `telnet` - can't solve




### Editors

#### WORK!

- [x] `vi`
- [x] `vim`

#### NOT-WORK :(

- [] `nano` - Error opening terminal: xterm-256color.


### Programming Languages

#### WORK!

- [x] `perl`
- [x] `ruby`
- [x] `irb`

#### NOT-WORK :(

- [] `java` - ... FillMatcher: failed to create CFNumberFormatter There do not ...
- [] `javac` - ... FillMatcher: failed to create CFNumberFormatter There do not ...