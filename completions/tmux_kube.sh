#!/bin/bash

# Get current context, you must have the $KUBECONFIG env var set
CONTEXT=$(grep "current-context:" "$KUBECONFIG" | sed "s/current-context: //")

if [ -n "$CONTEXT" ]; then
  echo "kubecontext: ${CONTEXT%%.*}"
fi
