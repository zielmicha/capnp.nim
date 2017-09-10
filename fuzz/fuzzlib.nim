
template runFuzz* =
  when defined(fuzz):
    proc abort() {.importc.}

    signal(SIGINT, SIG_DFL)
    signal(SIGSEGV, SIG_DFL)
    signal(SIGABRT, SIG_DFL)
    # signal(SIGFPE, SIG_DFL)
    signal(SIGILL, SIG_DFL)
    signal(SIGBUS, SIG_DFL)

    try:
      main()
    except:
      echo getCurrentExceptionMsg()
      abort()
  else:
    main()
