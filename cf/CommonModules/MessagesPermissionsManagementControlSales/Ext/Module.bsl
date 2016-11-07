////////////////////////////////////////////////////////////////////////////////
// GENERAL IMPLEMENTATION OF REMOTE ADMINISTRATION MESSAGES PROCESSING
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// {http://www.1c.ru/1CFresh/Application/Permissions/Control/a.b.c.d}InfobasePermissionsRequestProcessed
//
// Parameters:
//  IDRequest - UUID - id of the query on external resources use.
//  ProcessingResult - EnumRef.QueryProcessingResultsForExternalResourcesUseSaaS,
//  ErrorInfo - ObjectXDTO {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription.
//
Procedure UndividedSessionQueryProcessed(Val PackageIdentifier, Val ProcessingResult, Val ErrorInfo) Export
	
	QueryProcessed(PackageIdentifier, ProcessingResult);
	
EndProcedure

// {http://www.1c.ru/1CFresh/Application/Permissions/Control/a.b.c.d}ApplicationPermissionsRequestProcessed
//
// Parameters:
//  IDRequest - UUID - id of the query on external resources use.
//  ProcessingResult - EnumRef.QueryProcessingResultsForExternalResourcesUseSaaS,
//  ErrorInfo - ObjectXDTO {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription.
//
Procedure SplitSessionQueryProcessed(Val PackageIdentifier, Val ProcessingResult, Val ErrorInfo) Export
	
	QueryProcessed(PackageIdentifier, ProcessingResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure QueryProcessed(Val PackageIdentifier, Val ProcessingResult)
	
	BeginTransaction();
	
	Try
		
		Manager = WorkInSafeModeServiceSaaS.PackageApplicationManager(PackageIdentifier);
		
		If ProcessingResult = Enums.QueryProcessingResultsForExternalResourcesUseSaaS.QueryApproved Then
			Manager.FinishRequestsApplicationOnExternalResourcesUse();
		Else
			Manager.CancelRequestsApplicationOnExternalResourcesUse();
		EndIf;
		
		WorkInSafeModeServiceSaaS.SetPackageProcessingResult(ProcessingResult);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

