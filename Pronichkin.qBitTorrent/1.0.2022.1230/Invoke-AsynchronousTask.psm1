Set-StrictMode -Version 'Latest'

 <# Sample usage:

   #region    Standard decoration for invoking asynchronous task

      # documentation
        $methodName  = 'LoginAsync'

        $methodParam = @(
            $Credential.UserName                          # name
            $Credential.GetNetworkCredential().Password   # name
        )

        $taskParam   = @{
            InputObject = $client
            Name        = $methodName
            Parameter   = $methodParam
        }
      # this should return System.Threading.Tasks.VoidTaskResult
        $result      = Invoke-AsynchronousTask @taskParam

   #endregion Standard decoration for invoking asynchronous task

#>

function
Invoke-AsynchronousTask
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Object]
    )]
    
    Param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Object]
      # Object
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true
        )]
        [System.String]
      # Method name
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Object[]]
      # Method parameter(s)
        $Parameter = @()
    )

    Begin
    {}

    Process
    {
      # each method seems to require a Cancellation token as the last parameter

      # https://docs.microsoft.com/dotnet/api/system.threading.cancellationtoken.-ctor
        $tokenParam = @(        
            $false      # canceled
        )
        $token = [System.Threading.CancellationToken]::new.Invoke( $tokenParam )

        $Parameter += $token

      # invoke method

        $method = $InputObject.$Name
        $task   = $method.Invoke( $Parameter )

      # wait for completion

        Write-Message -Channel Debug -Message "$Name, waiting"

     <# either of the following will work for successful task, but will
        throw an error in case task fails

        $test.Wait()
        [System.Threading.Tasks.Task]::WaitAll( $test )
      #>

        [System.Void]$task.AsyncWaitHandle.WaitOne()

        Write-Message -Channel Debug -Message "$Name, done"

      # process result

        switch
        (
            $task.Status
        )
        {
            ([System.Threading.Tasks.TaskStatus]::Canceled)
            {
                throw "$Name timed out"
            }

            ([System.Threading.Tasks.TaskStatus]::RanToCompletion)
            {
                return $task.Result
            }

            ([System.Threading.Tasks.TaskStatus]::Faulted)
            {
                throw $task.Exception.InnerException  #  .InnerException
            }

            default
            {
                throw $task.Exception.InnerException.StatusCode
            }
        }        
    }

    End
    {}
}