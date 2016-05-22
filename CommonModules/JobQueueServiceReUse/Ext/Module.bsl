///////////////////////////////////////////////////////////////////////////////////
// JobQueueServiceReUse: Work with the jobs queue.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns a match of methods names to their
// aliases (uppercase) for call from the jobs queue.
//
// Returns:
//  FixedMatch
//   Key - The
//   Value method alias - Method name for call.
//
Function AccordanceMethodNamesToAliases() Export
	
	Result = New Map;
	
	// For backward compatibility.
	AllowedMethods = New Array;
	JobQueueOverridable.GetJobQueueAllowedMethods(AllowedMethods);
	For Each MethodName IN AllowedMethods Do
		Result.Insert(Upper(MethodName), MethodName);
	EndDo;
	
	MethodsConfiguration = New Map;
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenYouDefineAliasesHandlers(MethodsConfiguration);
	EndDo;
	
	// Determine service procedures methods to process jobs errors.
	MethodsConfiguration.Insert("JobQueueService.ProcessError");
	MethodsConfiguration.Insert("JobQueueService.RemoveErrorDataProcessorsJobs");
	
	JobQueueOverridable.WhenYouDefineAliasesHandlers(MethodsConfiguration);
	
	For Each KeyAndValue IN MethodsConfiguration Do
		Result.Insert(Upper(KeyAndValue.Key),
			?(IsBlankString(KeyAndValue.Value), KeyAndValue.Key, KeyAndValue.Value));
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns match of errors handlers to methods aliases for
// which they are called (uppercase).
//
// Returns:
//  FixedMatch
//   Key - The
//   Value method alias - Full name of the handler method.
//
Function MapHandlersErrorsAliases() Export
	
	ErrorHandlers = New Map;
	
	// Fill in errors embedded handlers.
	ErrorHandlers.Insert("JobQueueService.ProcessError","JobQueueService.RemoveErrorDataProcessorsJobs");
	ErrorHandlers.Insert("JobQueueService.RemoveErrorDataProcessorsJobs","JobQueueService.RemoveErrorDataProcessorsJobs");
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.JobQueue\WhenDefiningHandlersErrors");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenDefiningHandlersErrors(ErrorHandlers);
	EndDo;
	
	JobQueueOverridable.WhenDefiningHandlersErrors(ErrorHandlers);
	
	Result = New Map;
	For Each KeyAndValue IN ErrorHandlers Do
		Result.Insert(Upper(KeyAndValue.Key), KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns a description of queue jobs parameters.
//
// Returns:
//  ValueTable - description of parameters, column.
//   Name - String - parameter name.
//   NameUpper - String - parameter name uppercase.
//   Field - String - parameter storage field in the queue table.
//   Type - TypeDescription - allowed parameter value types.
//   Filter - Boolean - parameter can be used for filter.
//   Insert - Boolean - parameter can be specified
//    while adding job to the queue.
//   Update - Boolean - parameter can be changed.
//   Pattern - Boolean - parameter can be changed
//    for jobs created according to the template.
//   DataSeparation - Boolean - parameter is used only
//    by separated jobs while working.
//   ValueForUndividedJobs - String - value that
//     should be returned from API for the divided
//     parameters of undivided jobs (as a string suitable for substitution to the query texts).
//
Function JobQueueParameters() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("NameUpper", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Field", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Result.Columns.Add("Filter", New TypeDescription("Boolean"));
	Result.Columns.Add("Insert", New TypeDescription("Boolean"));
	Result.Columns.Add("Update", New TypeDescription("Boolean"));
	Result.Columns.Add("Pattern", New TypeDescription("Boolean"));
	Result.Columns.Add("DataSeparation", New TypeDescription("Boolean"));
	Result.Columns.Add("ValueForUndividedJobs", New TypeDescription("String"));
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "DataArea";
	ParameterDescription.Field = "DataAreaAuxiliaryData";
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.DataSeparation = True;
	ParameterDescription.ValueForUndividedJobs = "-1";
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ID";
	ParameterDescription.Field = "Ref";
	TypeArray = New Array();
	CatalogsJobs = JobQueueServiceReUse.GetCatalogsJobs();
	For Each CatalogJobs IN CatalogsJobs Do
		TypeArray.Add(TypeOf(CatalogJobs.EmptyRef()));
	EndDo;
	ParameterDescription.Type = New TypeDescription(TypeArray);
	ParameterDescription.Filter = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Use";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Boolean");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	ParameterDescription.Pattern = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ScheduledStartTime";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Date");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "JobState";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("EnumRef.JobStates");
	ParameterDescription.Filter = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ExclusiveExecution";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Boolean");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Pattern";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("CatalogRef.QueueJobsTemplates");
	ParameterDescription.Filter = True;
	ParameterDescription.DataSeparation = True;
	ParameterDescription.ValueForUndividedJobs = "UNDEFINED";
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "MethodName";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("String");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Parameters";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Array");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Key";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("String");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "RestartIntervalOnFailure";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Schedule";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("ScheduledJobSchedule, Undefined");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "RestartCountOnFailure";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	For Each ParameterDescription IN Result Do
		ParameterDescription.NameUpper = Upper(ParameterDescription.Name);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns allowed comparison kinds to filter queue jobs.
Function KindsCompareFilterJobs() Export
	
	Result = New Map;
	Result.Insert(ComparisonType.Equal, "=");
	Result.Insert(ComparisonType.NotEqual, "<>");
	Result.Insert(ComparisonType.InList, "In");
	Result.Insert(ComparisonType.NotInList, "NOT IN");
	
	Return New FixedMap(Result);
	
EndFunction

// Returns query text part of receiving jobs to return it via the application interface.
//
// Parameters:
//  CatalogJobs - CatalogManager,
//  manager catalog for which queue jobs are composed. Used to
//  filter selection fields that are applied not for all jobs catalogs.
//
Function JobQueueSelectionFields(Val CatalogJobs = Undefined) Export
	
	SelectionFields = "";
	For Each ParameterDescription IN JobQueueServiceReUse.JobQueueParameters() Do
		
		If Not IsBlankString(SelectionFields) Then
			SelectionFields = SelectionFields + "," + Chars.LF;
		EndIf;
		
		FieldDetailsSample = "Queue." + ParameterDescription.Field + " AS " + ParameterDescription.Name;
		
		If CatalogJobs <> Undefined Then
			
			If ParameterDescription.DataSeparation Then
				
				If Not CommonUseReUse.IsSeparatedConfiguration() OR Not CommonUse.IsSeparatedMetadataObject(CatalogJobs, CommonUseReUse.SupportDataSplitter()) Then
					
					FieldDetailsSample = ParameterDescription.ValueForUndividedJobs + " AS " + ParameterDescription.Name;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		SelectionFields = SelectionFields + Chars.Tab + FieldDetailsSample;
		
	EndDo;
	
	Return SelectionFields;
	
EndFunction

// Returns catalogs managers array that can be used
// to store jobs of the jobs queue.
//
Function GetCatalogsJobs() Export
	
	ArrayCatalog = New Array();
	ArrayCatalog.Add(Catalogs.JobQueue);
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
		ModuleJobQueueServiceDataSeparation.OnFillingCatalogsJobs(ArrayCatalog);
	EndIf;
	
	Return ArrayCatalog;
	
EndFunction

#EndRegion
