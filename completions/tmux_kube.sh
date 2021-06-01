#!/bin/bash

# Get current context, you must have the $KUBECONFIG env var set
CONTEXT=$(cat $KUBECONFIG | grep "current-context:" | sed "s/current-context: //")

if [ -n "$CONTEXT" ]; then
    echo "Current context: ${CONTEXT%%.*}"
fi
