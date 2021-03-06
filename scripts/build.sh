#!/bin/bash

# Erlang init
. $HOME/erlang/R16B02-basho8/activate

# Golang init
export REAL_GOPATH=$GOPATH
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
gvm use go1.5
export GOPATH=$REAL_GOPATH
export PATH=$PATH:$GOPATH/bin:$HOME/.gvm/gos/go1.4/bin

# Cleanup, compile, package
cd $GOPATH/src/github.com/basho-labs/riak-mesos
make
make package
