<# 
.DESCRIPTION
Here I am trying samples to learn how to use PowerShell jobs with Exchange tasks to accelerate somes tasks.
.SYNOPSIS
The below sample is taken from the follwing Web Site (see .LINK section)

.LINK
https://en.get-mailbox.org/using-powershell-background-jobs-can-help-you-speed-up-exchange-tasks-part-1/

#>

# Query all mailbox databases that are members of a DAG and that are not marked as
#  recovery databases.
$DAGDbs = Get-MailboxDatabase | Where-Object { $_.mastertype -eq "DatabaseAvailabilityGroup" -and $_.recovery -ne "true" }

# Use a Foreach loop to process each database.
ForEach ($DAGDb in $DAGDbs) {
	
	# Check the running status of jobs generated by this script to help throttle the
	#  concurrent jobs.
	$CheckJobs = Get-Job -Name GetMailboxes* | Where-Object { $_.State -eq 'Running' }
	
	# Use the If statement to throttle the number of concurrent jobs to four.
	if ($CheckJobs.count -le 3) {
		
		# When the number of running jobs is less than or equal to three, start
		#  another job using the DAG databases currently being processed within
		#  the ForEach loop.
		Start-Job -Name "GetMailboxes $DAGDb" -InitializationScript { Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 } `
		-ArgumentList ($DAGDb.name) -ScriptBlock {
			Get-Mailbox -Database $Args[0] -ResultSize Unlimited
		}
		
		# Process the else statement if more than four jobs are running.
	} else {
		# Check the jobs and wait until one of them finishes.  Then kick off
		#  another Start-Job.
		$CheckJobs | Wait-Job -Any
		
		# Start a job with the DAG database currently being processed.  This job
		#  ensures that the current pipeline object is not skipped.
		Start-Job -Name "GetMailboxes $DAGDb" -InitializationScript { Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 } `
		-ArgumentList ($DAGDb.name) -ScriptBlock {
			Get-Mailbox -Database $Args[0] -ResultSize unlimited
		}
	}
}

# Dump all the jobs from this script into the $Mailboxes variable.
$Mailboxes = Get-Job -Name GetMailboxes* | Receive-Job
# Clean up the jobs from this session.
do {
	$CheckJobs = Get-Job -Name GetMailboxes* | Where-Object { $_.State -eq 'Running' }
} until ($CheckJobs -eq $null)

Get-Job -Name GetMailboxes* | Remove-Job