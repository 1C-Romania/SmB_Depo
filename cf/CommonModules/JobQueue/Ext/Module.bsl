////////////////////////////////////////////////////////////////////////////////
// JobQueue: Work with jobs queue.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Main  procedures and functions.

// All methods available in API use job parameters. Use of
// a particular parameter depends on the method and, in some
// cases, values of other parameters. For more information, see description of particular methods.
//
// Parameter description:
//   DataArea - Number - value of a separator of the job data area. 
//    D1 for unseparated jobs. If a session separation is
//    set, then the session value is always used.
//   ID - CatalogRef.JobQueue,
//     CatalogRef.JobQueueDataAreas - job ID .
//   Use - Boolean - shows that a job is used.
//   ScheduledStartTime - Date (DateTime) - date
//    of the scheduled job start (in the data area time zone).
//   JobState - EnumRef.JobStates - Job state in the queue.
//   ExclusiveExecution - Boolean - If the check box is selected,
//    then the job will be completed even if a lock of session start in the data area is set. If there are
//    jobs with this check box in the area, they will be completed first.
//   Pattern - CatalogRef.QueueJobsTemplates - job template used
//     only for separated queue jobs.
//   MethodName - String - Method name (or alias) of the job handler. It
//    is not used for jobs created from template.
//    Only methods for which aliases are registered in the event can be used.
//    StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers
//   Parameters - Array - Parameters to be passed to the job handler.
//   Key  - String - job key. Duplicate jobs with the same key
//    or method name can not be used within one data area.
//   RestartIntervalOnFailure - Number - Timeout in seconds
//    before restarting a job if it was aborted. It is
//    calculated from the unsuccessful attempt to complete a job. Makes sense only
//    together with parameter RestartCountOnFailure. 
//   Schedule - JobSchedule - Job completion
//    schedule. if it is not specified - the job will be completed just once.
//   RestartCountOnFailure - Number - Number of attempts to complete a job again if it was aborted.

// Receives jobs from the queue by a set filter.
// Incosistent data might be received.
// Parameters:
//  Filter - Structure, Array - values by which jobs are to be filtered. 
//  Possible structure keys:
//   DataArea 
//   MethodName
//   Identifier
//   JobState
//   Key
//   Template
//   Usage
//  Also an array of structures can be passed - filter description with the following keys:
//   ComparisonType - ComparisonType - possible values are only.
//    ComparisonKind.Equal
//    ComparisonKind.NotEqual
//    ComparisonKind.InList
//    ComparisonKind.NotInList
//   Value - Filter value, for comparison kinds InList and NotInList - values array.
//    For comparison kinds Equal / NotEqual - values themselves.
//  All filter conditions are grouped by AND. 
// Return value:
//  ValueTable - table of found jobs. Columns correspond to the job parameters.
//
Function GetJobs(Val Filter) Export
	
	ValidateJobParameters(Filter, "Filter");
	
	// Generate a table with filter conditions.
	TableConditions = New ValueTable;
	TableConditions.Columns.Add("Field", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	TableConditions.Columns.Add("ComparisonType", New TypeDescription("ComparisonType"));
	TableConditions.Columns.Add("Parameter", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	TableConditions.Columns.Add("Value");
	
	ParameterDescriptions = JobQueueServiceReUse.JobQueueParameters();
	
	ReceiveSplit = True;
	GetUnseparated = True;
	
	For Each KeyAndValue IN Filter Do
		
		ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
		
		If ParameterDescription.DataSeparation Then
			ControlDivision = True;
		Else
			ControlDivision = False;
		EndIf;
		
		If TypeOf(KeyAndValue.Value) = Type("Array") Then
			For IndexOf = 0 To KeyAndValue.Value.UBound() Do
				FilterDescription = KeyAndValue.Value[IndexOf];
				
				Condition = TableConditions.Add();
				Condition.Field = ParameterDescription.Field;
				Condition.ComparisonType = FilterDescription.ComparisonType;
				Condition.Parameter = ParameterDescription.Name + FormatIndex(IndexOf);
				Condition.Value = FilterDescription.Value;
				
				If ControlDivision Then
					FilterDefinitionsByDivisionCatalogs(
						FilterDescription.Value,
						ParameterDescription,
						ReceiveSplit,
						GetUnseparated);
				EndIf;
				
			EndDo;
		Else
			
			Condition = TableConditions.Add();
			Condition.Field = ParameterDescription.Field;
			Condition.ComparisonType = ComparisonType.Equal;
			Condition.Parameter = ParameterDescription.Name;
			Condition.Value = KeyAndValue.Value;
			
			If ControlDivision Then
				FilterDefinitionsByDivisionCatalogs(
					KeyAndValue.Value,
					ParameterDescription,
					ReceiveSplit,
					GetUnseparated);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Prepare query
	Query = New Query;
	
	JobsDataAreasSplitter = CommonUseReUse.SupportDataSplitter();
	
	CatalogsJobs = JobQueueServiceReUse.GetCatalogsJobs();
	QueryText = "";
	For Each CatalogJobs IN CatalogsJobs Do
		
		Cancel = False;
		
		//SB
		//CatalogName = CatalogJobs.CreateItem().Metadata().FullName();
		CatalogName = Metadata.FindByType(TypeOf(CatalogJobs)).FullName();
		//SB End
		
		If Not ReceiveSplit Then
			
			If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(CatalogName, JobsDataAreasSplitter) Then
				Continue;
			EndIf;
			
		EndIf;
		
		If Not GetUnseparated Then
			
			If Not CommonUseReUse.IsSeparatedConfiguration() OR Not CommonUseReUse.IsSeparatedMetadataObject(CatalogName, JobsDataAreasSplitter) Then
				Continue;
			EndIf;
			
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		SelectionFields = JobQueueServiceReUse.JobQueueSelectionFields(CatalogName);
		
		ConditionsString = "";
		If TableConditions.Count() > 0 Then
			
			KindsCompare = JobQueueServiceReUse.KindsCompareFilterJobs();
			
			For Each Condition IN TableConditions Do
				
				If Condition.Field = JobsDataAreasSplitter Then
					If Not CommonUseReUse.IsSeparatedConfiguration() OR Not CommonUseReUse.IsSeparatedMetadataObject(CatalogName, JobsDataAreasSplitter) Then
						Cancel = True;
						Continue;
					EndIf;
				EndIf;
				
				If Not IsBlankString(ConditionsString) Then
					ConditionsString = ConditionsString + Chars.LF + Chars.Tab + "AND ";
				EndIf;
				
				ConditionsString = ConditionsString + "Queue." + Condition.Field + " " + 
					KindsCompare.Get(Condition.ComparisonType) + " (&" + Condition.Parameter + ")";
				
				Query.SetParameter(Condition.Parameter, Condition.Value);
			EndDo;
			
		EndIf;
		
		If Cancel Then
			Continue;
		EndIf;
		
		If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(CatalogName, CommonUseReUse.SupportDataSplitter()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
				"SELECT
				|" + SelectionFields + ",
				|	ISNULL(TimeZone.Value, """") AS
				|TimeZone
				|	FROM %1 AS Queue LEFT JOIN Constant.TimeZoneDataArea
				|		AS TimeZone BY Queue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData",
				CatalogJobs.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
				"SELECT
				|" + SelectionFields + ",
				|	"""" AS TimeZone
				|FROM
				|	%1 AS Queue",
				CatalogJobs.EmptyRef().Metadata().FullName());
			
		EndIf;
		
		If Not IsBlankString(ConditionsString) Then
			
			QueryText = QueryText + "
			|WHERE
			|	" + ConditionsString;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(QueryText) Then
		Raise NStr("en='Incorrect filter value - no catalog which jobs satisfy the filter conditions is found.';ru='Некорректное значение отбора - не обнаружено на одного справочника, задания из которого подходили бы под условия в отборе!'");
	EndIf;
	
	Query.Text = QueryText;
	
	// Data receiving
	If TransactionActive() Then
		Result = Query.Execute().Unload();
	Else
		Result = CommonUse.ExecuteQueryBeyondTransaction(Query).Unload();
	EndIf;
	
	// Casting results
	Result.Columns.Schedule.Name = "ScheduleStorage";
	Result.Columns.Parameters.Name = "ParametersStorage";
	Result.Columns.Add("Schedule", New TypeDescription("ScheduledJobSchedule, Undefined"));
	Result.Columns.Add("Parameters", New TypeDescription("Array"));
	
	For Each JobRow IN Result Do
		JobRow.Schedule = JobRow.ScheduleStorage.Get();
		JobRow.Parameters = JobRow.ParametersStorage.Get();
		
		TimeZoneAreas = JobRow.TimeZone;
		If Not ValueIsFilled(TimeZoneAreas) Then
			TimeZoneAreas = Undefined;
		EndIf;
		
		JobRow.ScheduledStartTime = 
			ToLocalTime(JobRow.ScheduledStartTime, TimeZoneAreas);
	EndDo;
	
	Result.Columns.Delete("ScheduleStorage");
	Result.Columns.Delete("ParametersStorage");
	Result.Columns.Delete("TimeZone");
	
	Return Result;
	
EndFunction

// Adds a new job to the queue.
// If there is a call, object lock is set for the job in the transaction.
// 
// Parameters: 
//  JobParameters - Structure - Added job parameters, possible keys:
//   DataArea
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution.
//   MethodName - mandatory to be specified.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RepetitionsQuantityOnFailure
//
// Returns: 
//  CatalogRef.JobQueue, CatalogRef.JobQueueDataAreas - Identifier of the job that you added.
// 
Function AddJob(JobParameters) Export
	
	ValidateJobParameters(JobParameters, "Insert");
	
	// Check method name
	If Not JobParameters.Property("MethodName") Then
		Raise(NStr("en='Obligatory task parameter MethodName is not specified';ru='Не задан обязательный параметр задания ИмяМетода'"));
	EndIf;
	
	ValidateRegistrationHandlerTasks(JobParameters.MethodName);
	
	// Check for key uniqueness.
	If JobParameters.Property("Key") AND ValueIsFilled(JobParameters.Key) Then
		Filter = New Structure;
		Filter.Insert("MethodName", JobParameters.MethodName);
		Filter.Insert("Key", JobParameters.Key);
		Filter.Insert("DataArea", JobParameters.DataArea);
		Filter.Insert("JobState", New Array);
		
		// Ignore completed.
		FilterDescription = New Structure;
		FilterDescription.Insert("ComparisonType", ComparisonType.NotEqual);
		FilterDescription.Insert("Value", Enums.JobStates.Completed);
		
		Filter.JobState.Add(FilterDescription);
		
		If GetJobs(Filter).Count() > 0 Then
			Raise GetJobsWithSameKeyDuplicationErrorMessage();
		EndIf;
	EndIf;
	
	// Defaults
	If Not JobParameters.Property("Use") Then
		JobParameters.Insert("Use", True);
	EndIf;
	
	PlannedMomentOfStart = Undefined;
	If JobParameters.Property("ScheduledStartTime", PlannedMomentOfStart) Then
		
		StandardProcessing = True;
		If CommonUseReUse.IsSeparatedConfiguration() Then
			
			ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
			ModuleJobQueueServiceDataSeparation.WhenDefiningScheduledDateOfLaunch(
				JobParameters,
				PlannedMomentOfStart,
				StandardProcessing);
			
		EndIf;
		
		If StandardProcessing Then
			PlannedMomentOfStart = ToUniversalTime(PlannedMomentOfStart);
		EndIf;
		
		JobParameters.Insert("ScheduledStartTime", PlannedMomentOfStart);
		
		MomentOfStartSpecified = True;
		
	Else
		
		JobParameters.Insert("ScheduledStartTime", CurrentUniversalDate());
		MomentOfStartSpecified = False;
		
	EndIf;
	
	// Types saved in the value storage.
	If JobParameters.Property("Parameters") Then
		JobParameters.Insert("Parameters", New ValueStorage(JobParameters.Parameters));
	Else
		JobParameters.Insert("Parameters", New ValueStorage(New Array));
	EndIf;
	
	If JobParameters.Property("Schedule") 
		AND JobParameters.Schedule <> Undefined Then
		
		JobParameters.Insert("Schedule", New ValueStorage(JobParameters.Schedule));
	Else
		JobParameters.Insert("Schedule", Undefined);
	EndIf;
	
	// Creating a job record.
	
	CatalogForTask = Catalogs.JobQueue;
	StandardProcessing = True;
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
		RedefinedCatalog = ModuleJobQueueServiceDataSeparation.OnChoiceCatalogForTasks1(JobParameters);
		If RedefinedCatalog <> Undefined Then
			CatalogForTask = RedefinedCatalog;
		EndIf;
	EndIf;
	
	Task = CatalogForTask.CreateItem();
	For Each ParameterDescription IN JobQueueServiceReUse.JobQueueParameters() Do
		If JobParameters.Property(ParameterDescription.Name) Then
			If ParameterDescription.DataSeparation Then
				If Not CommonUseReUse.IsSeparatedConfiguration() OR Not CommonUse.IsSeparatedMetadataObject(Task.Metadata(), CommonUseReUse.SupportDataSplitter()) Then
					Continue;
				EndIf;
			EndIf;
			Task[ParameterDescription.Field] = JobParameters[ParameterDescription.Name];
		EndIf;
	EndDo;
	
	If Task.Use
		AND (MomentOfStartSpecified OR JobParameters.Schedule = Undefined) Then
			
		Task.JobState = Enums.JobStates.Planned;
	Else
		Task.JobState = Enums.JobStates.NotPlanned;
	EndIf;
	
	RefTask = CatalogForTask.GetRef();
	Task.SetNewObjectRef(RefTask);
	
	If TransactionActive() Then
		
		LockDataForEdit(RefTask);
		// Lock is automatically removed once the transaction is complete.
	EndIf;
	
	CommonUse.AuxilaryDataWrite(Task);
	
	Return Task.Ref;
	
EndFunction

// Changes a job with the specified ID.
// If there is a call, object lock is set for the job in the transaction.
//   
// Parameters: 
//  ID - CatalogRef.JobQueue, CatalogRef.JobQueueDataAreas - Job
//  ID JobParameters - Structure - Parameters to be set
//  for the job, possible keys:
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution
//   MethodName.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RepetitionsQuantityOnFailure
//   
//   If a job is created from template, the following
//   keys can be specified: Use.
// 
Procedure ChangeTask(ID, JobParameters) Export
	
	ValidateJobParameters(JobParameters, "Update");
	
	Task = TasksDetailsOnIdIdentificator(ID);
	
	// Check an attempt to change a job of another area.
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData()
		AND Task.DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(GetAnotherAreaDataGettingExceptionText());
	EndIf;
	
	// Check an attempt to change job parameters with a specified template.
	If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(
				ID.Metadata().FullName(),
				CommonUseReUse.SupportDataSplitter()
			) Then
		If ValueIsFilled(Task.Pattern) Then
			ParameterDescriptions = JobQueueServiceReUse.JobQueueParameters();
			For Each KeyAndValue IN JobParameters Do
				ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
				If Not ParameterDescription.Pattern Then
					MessagePattern = NStr("en='Queue job with ID %1 is created from template.
		|Cannot change  parameter %2 of jobs with set template.';ru='Задание очереди с идентификатором %1 создано на основе шаблона.
		|Изменение параметра %2 заданий с установленным шаблоном запрещено.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						ID, ParameterDescription.Name);
					Raise(MessageText);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	// Check for key uniqueness.
	If JobParameters.Property("Key") AND ValueIsFilled(JobParameters.Key) Then
		Filter = New Structure;
		Filter.Insert("MethodName", JobParameters.MethodName);
		Filter.Insert("Key", JobParameters.Key);
		Filter.Insert("DataArea", Task.DataArea);
		Filter.Insert("ID", New Array);
		
		// Ignore the variable itself.
		FilterDescription = New Structure;
		FilterDescription.Insert("ComparisonType", ComparisonType.NotEqual);
		FilterDescription.Insert("Value", ID);
		
		Filter.ID.Add(FilterDescription);
		
		If GetJobs(Filter).Count() > 0 Then
			Raise GetJobsWithSameKeyDuplicationErrorMessage();
		EndIf;
	EndIf;
	
	ScheduledStartTime = Undefined;
	If JobParameters.Property("ScheduledStartTime", ScheduledStartTime)
			AND ValueIsFilled(JobParameters.ScheduledStartTime) Then
		
		StandardProcessing = True;
		If CommonUseReUse.IsSeparatedConfiguration() Then
			
			ModuleJobQueueServiceDataSeparation = CommonUse.CommonModule("JobQueueServiceDataSeparation");
			ModuleJobQueueServiceDataSeparation.WhenDefiningScheduledDateOfLaunch(
				JobParameters,
				ScheduledStartTime,
				StandardProcessing);
			
		EndIf;
		
		If StandardProcessing Then
			ScheduledStartTime = ToUniversalTime(ScheduledStartTime);
		EndIf;
		
		JobParameters.Insert("ScheduledStartTime", ScheduledStartTime);
		
		MomentOfStartSpecified = True;
	Else
		MomentOfStartSpecified = False;
	EndIf;
	
	// Types saved in the value storage.
	If JobParameters.Property("Parameters") Then
		JobParameters.Insert("Parameters", New ValueStorage(JobParameters.Parameters));
	EndIf;
	
	If JobParameters.Property("Schedule")
		AND JobParameters.Schedule <> Undefined Then
		
		JobParameters.Insert("Schedule", New ValueStorage(JobParameters.Schedule));
	EndIf;
	
	// Reschedule a job.
	If Not JobParameters.Property("ScheduledStartTime", ScheduledStartTime)
		AND JobParameters.Property("Schedule") Then
		
		JobParameters.Insert("ScheduledStartTime", ScheduledStartTime);
	EndIf;
	
	// Lock writing jobs
	LockDataForEdit(ID);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add(ID.Metadata().FullName());
		LockItem.SetValue("Ref", ID);
		Block.Lock();
		
		// Creating a job record.
		
		If Not CommonUse.RefExists(ID) Then
			MessagePattern = NStr("en='Job with ID %1 to be changed is not found. Data area: %2';ru='Задание с идентификатором %1 к изменению не найдено. Область данных: %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID, Task.DataArea);
			Raise(MessageText);
		EndIf;
		
		Task = ID.GetObject();
		
		For Each ParameterDescription IN JobQueueServiceReUse.JobQueueParameters() Do
			If JobParameters.Property(ParameterDescription.Name) Then
				Task[ParameterDescription.Field] = JobParameters[ParameterDescription.Name];
			EndIf;
		EndDo;
		
		If Task.Use
			AND (MomentOfStartSpecified 
			OR Not JobParameters.Property("Schedule")
			OR JobParameters.Schedule = Undefined) Then
				
			Task.JobState = Enums.JobStates.Planned;
		Else
			Task.JobState = Enums.JobStates.NotPlanned;
		EndIf;
		
		CommonUse.AuxilaryDataWrite(Task);
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	If Not TransactionActive() Then // Otherwise, a lock will be removed once the transaction is complete.
		UnlockDataForEdit(ID);
	EndIf;
	
EndProcedure

// Deletes a job from the job queue.
// Deletion of tasks with the installed template is prohibited.
// If there is a call, object lock is set for the job in the transaction.
// 
// Parameters: 
//  ID - CatalogRef.JobQueue, CatalogRef.JobQueueDataAreas, - Job ID
// 
Procedure DeleteJob(ID) Export
	
	Task = ID.GetObject();
	
	If CommonUseReUse.IsSeparatedConfiguration() AND CommonUseReUse.IsSeparatedMetadataObject(
				Task.Metadata().FullName(),
				CommonUseReUse.SupportDataSplitter()
			) Then
		If ValueIsFilled(Task.Pattern) Then
			MessagePattern = NStr("en='Queue job with ID %1 is created from template.
		|Deletion of tasks with the installed template is prohibited.';ru='Задание очереди с идентификатором %1 создано на основе шаблона.
		|Удаление заданий с установленным шаблоном запрещено.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
			Raise(MessageText);
		EndIf;
	EndIf;
	
	LockDataForEdit(ID);
	
	Task.DataExchange.Load = True;
	CommonUse.DeleteAuxiliaryData(Task);
	
	If Not TransactionActive() Then // Otherwise, a lock is removed once the transaction is complete.
		UnlockDataForEdit(ID);
	EndIf;
	
EndProcedure

// Returns a job template by a predetermined scheduled job name from which it was created.
//
// Parameters:
//  Name - String - name
//   of the predefined scheduled job.
//
// Returns:
//  CatalogRef.QueueJobsTemplates - job template.
//
Function TemplateByName(Val Name) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	QueueJobsTemplates.Ref AS Ref
	|FROM
	|	Catalog.QueueJobsTemplates AS QueueJobsTemplates
	|WHERE
	|	QueueJobsTemplates.Name = &Name";
	Query.SetParameter("Name", Name);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		MessagePattern = NStr("en='job template with name %1 is not found.';ru='Не найден шаблон задания с именем %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Name);
		Raise(MessageText);
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.Ref;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Checks whether passed parameter structure complies
// with the subsystem requirements:
//  - keys content
//  - parameter types
//
// Parameters:
//  Parameters - Structure - job parameters.
//  Mode - String - mode in which parameters are to be checked.
//   Possible values:
//    Filter - checking filter parameters.
//    Insert - checking parameters to add.
//    Update - checking parameters to change.
// 
Procedure ValidateJobParameters(Parameters, Mode)
	
	If TypeOf(Parameters) <> Type("Structure") Then
		MessagePattern = NStr("en='Invalid type of the job parameters set is passed - %1';ru='Передан недопустимый тип набора параметров задания - %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, TypeOf(Parameters));
		Raise(MessageText);
	EndIf;
	
	Filter = Mode = "Filter";
	
	ParameterDescriptions = JobQueueServiceReUse.JobQueueParameters();
	
	KindsCompare = JobQueueServiceReUse.KindsCompareFilterJobs();
	
	DescriptionFilterKeys = New Array;
	DescriptionFilterKeys.Add("ComparisonType");
	DescriptionFilterKeys.Add("Value");
	
	For Each KeyAndValue IN Parameters Do
		ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
		If ParameterDescription = Undefined 
			OR Not ParameterDescription[Mode] Then
			
			MessagePattern = NStr("en='Invalid job parameter is passed - %1';ru='Передан недопустимый параметр задания - %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
				KeyAndValue.Key);
			Raise(MessageText);
		EndIf;
		
		If Filter AND TypeOf(KeyAndValue.Value) = Type("Array") Then
			// Filter descriptions array
			For Each FilterDescription IN KeyAndValue.Value Do
				If TypeOf(FilterDescription) <> Type("Structure") Then
					MessagePattern = NStr("en='Invalid type %1 in selection description collection %2 is passed';ru='Передан недопустимый тип %1 в коллекции описания отбора %2'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						TypeOf(FilterDescription), KeyAndValue.Key);
					Raise(MessageText);
				EndIf;
				
				// Check keys
				For Each KeyName IN DescriptionFilterKeys Do
					If Not FilterDescription.Property(KeyName) Then
						MessagePattern = NStr("en='Invalid filter description in the filter description collection %1 is passed.
		|There is no property %2.';ru='Передано недопустимое описание отбора в коллекции описания отбора %1.
		|Отсутствует свойство %2.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
							KeyAndValue.Key, KeyName);
						Raise(MessageText);
					EndIf;
				EndDo;
				
				// Check comparison kind
				If KindsCompare.Get(FilterDescription.ComparisonType) = Undefined Then
					MessagePattern = NStr("en='Invalid matching type in the selection description in the %1 selection description collection is passed';ru='Передан недопустимый вид сравнения в описании отбора в коллекции описания отбора %1'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						KeyAndValue.Key);
					Raise(MessageText);
				EndIf;
				
				// Check value
				If FilterDescription.ComparisonType = ComparisonType.InList
					OR FilterDescription.ComparisonType = ComparisonType.NotInList Then
					
					If TypeOf(FilterDescription.Value) <> Type("Array") Then
						MessagePattern = NStr("en='Invalid type %1 in the filter description in the filter description collection %2 is passed.
		|For matching type %3 the Array type is awaited.';ru='Передан недопустимый тип %1 в описании отбора в коллекции описания отбора %2.
		|Для вида сравнения %3 ожидается тип Массив.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
							TypeOf(FilterDescription.Value), KeyAndValue.Key, FilterDescription.ComparisonType);
						Raise(MessageText);
					EndIf;
					
					For Each FilterValue IN FilterDescription.Value Do
						ValidateValueInAccordanceToDescriptionParameter(FilterValue, ParameterDescription);
					EndDo;
				Else
					ValidateValueInAccordanceToDescriptionParameter(FilterDescription.Value, ParameterDescription);
				EndIf;
			EndDo;
		Else
			ValidateValueInAccordanceToDescriptionParameter(KeyAndValue.Value, ParameterDescription);
		EndIf;
	EndDo;
	
	// Data area
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		If Parameters.Property("DataArea") Then
			If Parameters.DataArea <> CommonUse.SessionSeparatorValue() Then
				Raise(NStr("en='In this session the reference to the data from the other data area is unavailable!';ru='В данном сеансе недопустимо обращение к данным из другой области данных!'"));
			EndIf;
		Else
			ParameterDescription = ParameterDescriptions.Find(Upper("DataArea"), "NameUpper");
			If ParameterDescription[Mode] Then
				Parameters.Insert("DataArea", CommonUse.SessionSeparatorValue());
			EndIf;
		EndIf;
		
	EndIf;
	
	// ScheduledStartTime
	If Parameters.Property("ScheduledStartTime")
		AND Not ValueIsFilled(Parameters.ScheduledStartTime) Then
		
		MessagePattern = NStr("en='Invalid value %1 of the job parameter %2 is passed';ru='Передано недопустимое значение %1 параметра задания %2'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
			Parameters.ScheduledStartTime, 
			ParameterDescriptions.Find(Upper("ScheduledStartTime"), "NameUpper").Name);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Procedure ValidateValueInAccordanceToDescriptionParameter(Val Value, Val ParameterDescription)
	
	If Not ParameterDescription.Type.ContainsType(TypeOf(Value)) Then
		MessagePattern = NStr("en='Invalid type %1 of the job parameter %2 is passed';ru='Передан недопустимый тип %1 параметра задания %2'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
			TypeOf(Value), ParameterDescription.Name);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Function FormatIndex(Val IndexOf)
	
	Return Format(IndexOf, "NZ=0; NG=")
	
EndFunction

Procedure ValidateRegistrationHandlerTasks(Val MethodName)
	
	If JobQueueServiceReUse.AccordanceMethodNamesToAliases().Get(Upper(MethodName)) = Undefined Then
		MessagePattern = NStr("en='%1 method alias for using as a job queue handler is not registered.';ru='Не зарегистрирован псевдоним метода %1 для использования в качестве обработчика задания очереди.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MethodName);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Function TasksDetailsOnIdIdentificator(Val ID)
	
	If Not ValueIsFilled(ID) OR Not CommonUse.RefExists(ID) Then
		MessagePattern = NStr("en='Invalid value %1 of the job parameter ID is passed';ru='Передано недопустимое значение %1 параметра задания Идентификатор'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
		Raise(MessageText);
	EndIf;
	
	Jobs = GetJobs(New Structure("ID", ID));
	If Jobs.Count() = 0 Then
		MessagePattern = NStr("en='Job queue with the %1 ID is not found';ru='Задание очереди с идентификатором %1 не найдено'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
		Raise(MessageText);
	EndIf;
	
	Return Jobs[0];
	
EndFunction

// Returns an error text if there is an attempt to complete two jobs with the same key.
//
// Returns:
// Row.
//
Function GetJobsWithSameKeyDuplicationErrorMessage() Export
	
	Return NStr("en=""Doubling of jobs with the same field value 'Key' unavailable."";ru=""Дублирование заданий с одинаковым значения поля 'Ключ' не допустимо.""");
	
EndFunction

// Returns an error text if there is an attempt to get
// a job list of another area from the session with set separator value.
//
// Returns:
// Row.
//
Function GetAnotherAreaDataGettingExceptionText()
	
	Return NStr("en='In this session the reference to the data from the other data area is unavailable!';ru='В данном сеансе недопустимо обращение к данным из другой области данных!'");
	
EndFunction

Procedure FilterDefinitionsByDivisionCatalogs(Val Value, Val ParameterDescription, ReceiveSplit, GetUnseparated)
	
	ValueType = TypeOf(Value);
	TypeArrayValues = New Array();
	TypeArrayValues.Add(ValueType);
	TypeDescription = New TypeDescription(TypeArrayValues);
	DefaultValue = TypeDescription.AdjustValue(
		ParameterDescription.ValueForUndividedJobs);
	If Value = DefaultValue Then
		
		ReceiveSplit = False;
		
	Else
		
		GetUnseparated = False;
		
	EndIf;
	
EndProcedure

#EndRegion
