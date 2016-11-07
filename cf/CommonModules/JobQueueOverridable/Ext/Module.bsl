///////////////////////////////////////////////////////////////////////////////////
// JobQueueOverridable: Work with undivided scheduled jobs.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Forms a list of queue jobs templates
//
// Parameters:
//  Patterns - String array. You should add the names
//   of predefined undivided scheduled jobs in the parameter
//   that should be used as a template for setting a queue.
//
Procedure ListOfTemplatesOnGet(Patterns) Export
	
EndProcedure

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("ExchangeWithSite.PerformJobExchange");
	
EndProcedure

// Fills in match of errors handlers methods to
// methods aliases when errors in which they are called occur.
//
// Parameters:
//  ErrorHandlers - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name - errors handler to call if an error occurs. 
//    Errors handler is called when the initial job is executed with an error. Errors handler is called in the same data
//    area that the initial job.
//    Errors handler method is considered to be enabled for a call by the queue mechanisms. 
//    Error handler parameters.:
//     JobParameters - Structure - Job queue parameters.
//      Parameters
//      AttemptNumber
//      RestartQuantityOnFailure
//      LastStartBeginDate
//
Procedure WhenDefiningHandlersErrors(ErrorHandlers) Export
	
EndProcedure

// Generates scheduled
// jobs table with the flag of usage in the service model.
//
// Parameters:
// UsageTable - ValueTable - table that should be filled in with the scheduled jobs a flag of usage, columns:
//  ScheduledJob - String - name of the predefined scheduled job.
//  Use - Boolean - True if scheduled job
//   should be executed in the service model. False - if it should not.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
EndProcedure

// Outdated. It is recommended to use ListOfTemplatesOnGet().
//
Procedure FillSeparatedScheduledJobList(SeparatedScheduledJobList) Export
	
EndProcedure

// Outdated. It is recommended to use WhenYouDefineAliasesHandlers().
//
Procedure GetJobQueueAllowedMethods(Val AllowedMethods) Export
	
EndProcedure

#EndRegion
