@{
    Name        = "Exception Handling"
    Description = "Tests SafeguardDotNet exception handling via the ExceptionTest tool"
    Tags        = @("core", "exceptions")

    Setup = {
        param($Context)
        # ExceptionTest tool uses the bootstrap admin — no extra objects needed.
        # Build the exception test project (already built by runner, but ensure it's ready).
    }

    Execute = {
        param($Context)

        Test-SgDnAssert "Exception test suite passes" {
            # The ExceptionTest tool runs its own internal assertions and exits with
            # code 0 on success, code 1 on failure. We just need to invoke it.
            Invoke-SgDnSafeguardTool -ProjectDir $Context.ExceptionTestDir `
                -Arguments "-a $($Context.Appliance) -u $($Context.AdminUserName) -x -p" `
                -StdinLine $Context.AdminPassword `
                -ParseJson $false
            $true
        }
    }

    Cleanup = {
        param($Context)
        # No objects created.
    }
}
