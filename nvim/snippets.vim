snippet     iferr
abbr        if err !=
alias ie
options     head
  if err != nil {
    return err
  }
