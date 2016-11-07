///////////////////////////////////////////////////////////////////////////////////
// The IB version update in service model subsystem.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Generates and saves data areas update plan to IB.
//
// Parameters:
//  LibraryID  - String - configuration name or
//  library identifier, AllHandlers    - Map - list of
//  all update handlers, MandatorydSeparateHandlers    - Map - mandatory
//    update handlers list with SharedData =
//  False, SourceIBVersion - String - infobase source
//  version, IBMetadataVersion - String - configuration version (from metadata).
//
Procedure GenerateDataAreaUpdatePlan(LibraryID, AllHandlers, 
	RequiredSeparateHandlers, OriginalVersionOfDB, MetadataIBVersion) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Not CommonUseReUse.CanUseSeparatedData() Then
		
		UpdateHandlers = AllHandlers.CopyColumns();
		For Each HandlerLine IN AllHandlers Do
			// Do not add mandatory (*) handlers by default when area update plan is being generated.
			If HandlerLine.Version = "*" Then
				Continue;
			EndIf;
			FillPropertyValues(UpdateHandlers.Add(), HandlerLine);
		EndDo;
		
		For Each RequiredProcessor IN RequiredSeparateHandlers Do
			HandlerLine = UpdateHandlers.Add();
			FillPropertyValues(HandlerLine, RequiredProcessor);
			HandlerLine.Version = "*";
		EndDo;
		
		DataAreaUpdatePlan = InfobaseUpdateService.UpdateHandlersInInterval(
			UpdateHandlers, OriginalVersionOfDB, MetadataIBVersion, True);
			
		PlanDescription = New Structure;
		PlanDescription.Insert("VersionFrom", OriginalVersionOfDB);
		PlanDescription.Insert("VersionOn", MetadataIBVersion);
		PlanDescription.Insert("Plan", DataAreaUpdatePlan);
		
		RecordManager = InformationRegisters.SubsystemVersions.CreateRecordManager();
		RecordManager.SubsystemName = LibraryID;
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.SubsystemVersions");
		LockItem.SetValue("SubsystemName", LibraryID);
		
		BeginTransaction();
		Try
			Block.Lock();
			
			RecordManager.Read();
			RecordManager.UpdatePlan = New ValueStorage(PlanDescription);
			RecordManager.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		EmptyUpdatePlan = DataAreaUpdatePlan.Rows.Count() = 0;
		
		If LibraryID = Metadata.Name Then
			// Configuration version can be set only if no library requires
			// update, otherwise, update mechanism in the areas will not be run and libraries will not be updated.
			EmptyUpdatePlan = False;
			
			// Check all plans for emptiness.
			Libraries = New ValueTable;
			Libraries.Columns.Add("Name", Metadata.InformationRegisters.SubsystemVersions.Dimensions.SubsystemName.Type);
			Libraries.Columns.Add("Version", Metadata.InformationRegisters.SubsystemVersions.Resources.Version.Type);
			
			SubsystemDescriptions  = StandardSubsystemsReUse.SubsystemDescriptions();
			For Each SubsystemName IN SubsystemDescriptions.Order Do
				SubsystemDescription = SubsystemDescriptions.ByNames.Get(SubsystemName);
				If Not ValueIsFilled(SubsystemDescription.MainServerModule) Then
					// Library has no module - there are no update handlers.
					Continue;
				EndIf;
				
				LibraryString = Libraries.Add();
				LibraryString.Name = SubsystemDescription.Name;
				LibraryString.Version = SubsystemDescription.Version;
			EndDo;
			
			Query = New Query;
			Query.SetParameter("Libraries", Libraries);
			Query.Text =
				"SELECT
				|	Libraries.Name AS Name,
				|	Libraries.Version AS Version
				|INTO Libraries
				|FROM
				|	&Libraries AS Libraries
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	Libraries.Name AS Name,
				|	Libraries.Version AS Version,
				|	SubsystemVersions.UpdatePlan AS UpdatePlan,
				|	CASE
				|		WHEN SubsystemVersions.Version = Libraries.Version
				|			THEN TRUE
				|		ELSE FALSE
				|	END AS Updated
				|FROM
				|	Libraries AS Libraries
				|		LEFT JOIN InformationRegister.SubsystemVersions AS SubsystemVersions
				|		BY Libraries.Name = SubsystemVersions.SubsystemName";
				
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add("InformationRegister.SubsystemVersions");
				LockItem.Mode = DataLockMode.Shared;
				Block.Lock();
				
				Result = Query.Execute();
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			Selection = Result.Select();
			While Selection.Next() Do
				
				If Not Selection.Updated Then
					EmptyUpdatePlan = False;
					
					CommentTemplate = NStr("en='Configuration version update has been performed before the %1 library version update';ru='Обновление версии конфигурации было выполнено до обновления версии библиотеки %1'");
					TextOfComment = StringFunctionsClientServer.PlaceParametersIntoString(CommentTemplate, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMonitorEvent(),
						EventLogLevel.Error,
						,
						,
						TextOfComment);
					
					Break;
				EndIf;
				
				If Selection.UpdatePlan = Undefined Then
					DescriptionUpdateYourPlan = Undefined;
				Else
					DescriptionUpdateYourPlan = Selection.UpdatePlan.Get();
				EndIf;
				
				If DescriptionUpdateYourPlan = Undefined Then
					EmptyUpdatePlan = False;
					
					CommentTemplate = NStr("en='Library update plan %1 has not been found';ru='Не найден план обновления библиотеки %1'");
					TextOfComment = StringFunctionsClientServer.PlaceParametersIntoString(CommentTemplate, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMonitorEvent(),
						EventLogLevel.Error,
						,
						,
						TextOfComment);
					
					Break;
				EndIf;
				
				If DescriptionUpdateYourPlan.VersionOn <> Selection.Version Then
					EmptyUpdatePlan = False;
					
					CommentTemplate = NStr("en='Incorrect library update plan
		|is found %1 An update to version plan is required %2, an update to version plan is found %3';ru='Обнаружен некорректный
		|план обновления библиотеки %1 Требуется план обновления на версию %2, найден план для обновления на версию %3'");
					TextOfComment = StringFunctionsClientServer.PlaceParametersIntoString(CommentTemplate, Selection.Name);
					WriteLogEvent(
						InfobaseUpdate.EventLogMonitorEvent(),
						EventLogLevel.Error,
						,
						,
						TextOfComment);
					
					Break;
				EndIf;
				
				If DescriptionUpdateYourPlan.Plan.Rows.Count() > 0 Then
					EmptyUpdatePlan = False;
					Break;
				EndIf;
				
			EndDo;
		EndIf;
		
		If EmptyUpdatePlan Then
			SetVersionForAllDataAreas(LibraryID, OriginalVersionOfDB, MetadataIBVersion);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Selects in the jobs queue a check
// box of using the job that corresponds to the scheduled job for postponed update execution.
//
// Parameters:
//  Use - Boolean - new value of the usage check box.
//
Procedure OnEnablePostponedUpdating(Val Use) Export
	
	Pattern = JobQueue.TemplateByName("DeferredInfobaseUpdate");
	
	JobFilter = New Structure;
	JobFilter.Insert("Pattern", Pattern);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	JobParameters = New Structure("Use", Use);
	JobQueue.ChangeTask(Tasks[0].ID, JobParameters);
	
EndProcedure

// Checks if the common part of the infobase update is executed.
//
Procedure BeforeInformationBaseUpdating() Export
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		SharedDataVersion = InfobaseUpdateService.IBVersion(Metadata.Name, True);
		If InfobaseUpdateService.NeedToDoUpdate(Metadata.Version, SharedDataVersion) Then
			Message = NStr("en='Common part of the infobase update is not executed.
		|Contact your administrator.';ru='Не выполнена общая часть обновления информационной базы.
		|Обратитесь к администратору.'");
			WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), EventLogLevel.Error,,, Message);
			Raise Message;
		EndIf;
	EndIf;
	
EndProcedure	

#EndRegion

#Region ServiceProceduresAndFunctions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"InfobaseUpdateServiceSaaS");
	
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
				"InfobaseUpdateServiceSaaS");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"InfobaseUpdateServiceSaaS");
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate"].Add(
			"InfobaseUpdateServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"InfobaseUpdateServiceSaaS");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
			"InfobaseUpdateServiceSaaS");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"InfobaseUpdateServiceSaaS");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

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
	
	AccordanceNamespaceAliases.Insert("InfobaseUpdateServiceSaaS.UpdateCurrentDataArea");
	
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
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataAreasUpdate";
	NewRow.Use       = True;
	
EndProcedure

// Called after IB data exclusive update is complete.
// 
// Parameters:
//   PreviousVersion       - String - subsystem version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - subsystem version after update.
//   ExecutedHandlers - ValueTree - list of the
//                                             executed procedures-processors of updating the subsystem grouped by the version number.
//                            Procedure of completed handlers bypass:
//
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Ha//ndler that can be run every time the version changes.
// 	Otherwise, Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
//   PutSystemChangesDescription - Boolean (return value)- if you set True, then display the form with updates description.
//   ExclusiveMode           - Boolean - shows that the update was executed in an exclusive mode.
//                                True - update was executed in the exclusive mode.
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		LockParameters = InfobaseConnections.GetDataAreaSessionLock();
		If Not LockParameters.Use Then
			Return;
		EndIf;
		LockParameters.Use = False;
		InfobaseConnections.SetDataAreaSessionLock(LockParameters);
		
	Else
		
		SwitchOffSoleMode = False;
		If Not ExclusiveMode() Then
			
			Try
				SetExclusiveMode(True);
				SwitchOffSoleMode = True;
			Except
				// Processing of the exception is not required.
				// Expected exception - error setting exclusive mode
				// because of the existence of other sessions nawhenmer when dynamic update configuration).
				// IN this case, fields update planning will be executed
				// considering possible competition during accessing metadata objects tables
				// separated in the Independently and jointly mode (it is less efficient
				// than execution in the exclusive mode.
			EndTry;
			
		EndIf;
		
		ScheduleDataAreaUpdate(True);
		
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.19";
	Handler.Procedure = "InfobaseUpdateServiceSaaS.TransferSubsystemsVersionsToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreasSubsystemVersions);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - required to get the list of the exception objects of the DIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.InformationRegisters.DataAreasSubsystemVersions);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DelecteSubsystemsVersions information
//  register to the SubsystemsVersions information DataAreasSubsystemVersions.
Procedure TransferSubsystemsVersionsToAuxiliaryData() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock();
		RegisterBlock = Block.Add("InformationRegister.DataAreasSubsystemVersions");
		RegisterBlock.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		QueryText =
		"SELECT
		|	ISNULL(DataAreasSubsystemVersions.DataAreaAuxiliaryData, DeleteVersionSubsystems.DataArea) AS DataAreaAuxiliaryData,
		|	ISNULL(DataAreasSubsystemVersions.SubsystemName, DeleteVersionSubsystems.SubsystemName) AS SubsystemName,
		|	ISNULL(DataAreasSubsystemVersions.Version, DeleteVersionSubsystems.Version) AS Version
		|FROM
		|	InformationRegister.DeleteVersionSubsystems AS DeleteVersionSubsystems
		|		LEFT JOIN InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
		|		BY DeleteVersionSubsystems.DataArea = DataAreasSubsystemVersions.DataAreaAuxiliaryData
		|			AND DeleteVersionSubsystems.SubsystemName = DataAreasSubsystemVersions.SubsystemName
		|WHERE
		|	DeleteVersionSubsystems.DataArea <> -1";
		Query = New Query(QueryText);
		
		DataAreasSubsystemVersions = InformationRegisters.DataAreasSubsystemVersions.CreateRecordSet();
		DataAreasSubsystemVersions.Load(Query.Execute().Unload());
		InfobaseUpdate.WriteData(DataAreasSubsystemVersions);
		
		SetDeleteubsystemVersions = InformationRegisters.DeleteVersionSubsystems.CreateRecordSet();
		InfobaseUpdate.WriteData(SetDeleteubsystemVersions);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data area update.

// Updates infobase version in the current data
// area and removes the sessions lock in the area if it
// is set previously.
//
Procedure UpdateCurrentDataArea() Export
	
	SetPrivilegedMode(True);
	
	InfobaseUpdate.RunInfobaseUpdate();
	
EndProcedure

// Selects all data areas with
// irrelevant versions and generates background jobs by
// the version update in them if needed.
//
// Parameters:
// LockAreas - Boolean - Set data areas sessions
//  lock during the areas update.
//
Procedure ScheduleDataAreaUpdate(Val LockAreas = True, Val LockMessage = "") Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If IsBlankString(LockMessage) Then
		LockMessage = Constants.LockMessageOnConfigurationUpdate.Get();
		If IsBlankString(LockMessage) Then
			LockMessage = NStr("en='System is locked to perform the update.';ru='Система заблокирована для выполнения обновления.'");
		EndIf;
	EndIf;
	LockParameters = InfobaseConnections.NewLockConnectionParameters();
	LockParameters.Begin = CurrentUniversalDate();
	LockParameters.Message = LockMessage;
	LockParameters.Use = True;
	LockParameters.Exclusive = True;
	
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		Return;
	EndIf;
	
	SharedDataVersion = InfobaseUpdateService.IBVersion(Metadata.Name, True);
	If InfobaseUpdateService.NeedToDoUpdate(MetadataVersion, SharedDataVersion) Then
		// Common data is not updated there
		// is no point in planning fields update.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|		LEFT JOIN InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
	|		BY DataAreas.DataAreaAuxiliaryData = DataAreasSubsystemVersions.DataAreaAuxiliaryData
	|			AND (DataAreasSubsystemVersions.SubsystemName = &SubsystemName)
	|		LEFT JOIN InformationRegister.DataAreasActivityRating AS DataAreasActivityRating
	|		BY DataAreas.DataAreaAuxiliaryData = DataAreasActivityRating.DataAreaAuxiliaryData
	|WHERE
	|	DataAreas.Status IN (VALUE(Enum.DataAreaStatuses.Used))
	|	AND (DataAreasSubsystemVersions.DataAreaAuxiliaryData IS NULL 
	|			OR DataAreasSubsystemVersions.Version <> &Version)
	|
	|ORDER BY
	|	ISNULL(DataAreasActivityRating.Rating, 9999999),
	|	DataArea";
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.SetParameter("Version", MetadataVersion);
	Result = CommonUse.ExecuteQueryBeyondTransaction(Query);
	If Result.IsEmpty() Then // Preliminary reading, dirty reading may occur.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	DataAreasSubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
	|WHERE
	|	DataAreasSubsystemVersions.DataAreaAuxiliaryData = &DataArea
	|	AND DataAreasSubsystemVersions.SubsystemName = &SubsystemName";
	Query.SetParameter("SubsystemName", Metadata.Name);
	
	Selection = Result.Select();
	While Selection.Next() Do
		KeyValues = New Structure;
		KeyValues.Insert("DataAreaAuxiliaryData", Selection.DataArea);
		KeyValues.Insert("SubsystemName", "");
		RecordKey = SaaSOperations.CreateAuxiliaryDataRecordKeyOfInformationRegister(
			InformationRegisters.DataAreasSubsystemVersions, KeyValues);
		
		BlockSetError = False;
		
		BeginTransaction();
		Try
			Try
				LockDataForEdit(RecordKey); // It will be cleared when the transaction is complete.
			Except
				BlockSetError = True;
				Raise;
			EndTry;
			
			Query.SetParameter("DataArea", Selection.DataArea);
		
			Block = New DataLock;
			
			LockItem = Block.Add("InformationRegister.DataAreasSubsystemVersions");
			LockItem.SetValue("DataAreaAuxiliaryData", Selection.DataArea);
			LockItem.SetValue("SubsystemName", Metadata.Name);
			LockItem.Mode = DataLockMode.Shared;
			
			LockItem = Block.Add("InformationRegister.DataAreas");
			LockItem.SetValue("DataAreaAuxiliaryData", Selection.DataArea);
			LockItem.Mode = DataLockMode.Shared;
			
			Block.Lock();
			
			Results = Query.ExecuteBatch();
			
			AreaString = Undefined;
			If Not Results[0].IsEmpty() Then
				AreaString = Results[0].Unload()[0];
			EndIf;
			VersionString = Undefined;
			If Not Results[1].IsEmpty() Then
				VersionString = Results[1].Unload()[0];
			EndIf;
			
			If AreaString = Undefined
				OR AreaString.Status <> Enums.DataAreaStatuses.Used
				OR (VersionString <> Undefined AND VersionString.Version = MetadataVersion) Then
				
				// Records do not correspond to the source criteria.
				CommitTransaction();
				Continue;
			EndIf;
			
			JobFilter = New Structure;
			JobFilter.Insert("MethodName", "InfobaseUpdateServiceSaaS.UpdateCurrentDataArea");
			JobFilter.Insert("Key", "1");
			JobFilter.Insert("DataArea", Selection.DataArea);
			Jobs = JobQueue.GetJobs(JobFilter);
			If Jobs.Count() > 0 Then
				// A job of area updates already presents.
				CommitTransaction();
				Continue;
			EndIf;
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , "InfobaseUpdateServiceSaaS.UpdateCurrentDataArea");
			JobParameters.Insert("Parameters"    , New Array);
			JobParameters.Insert("Key"         , "1");
			JobParameters.Insert("DataArea", Selection.DataArea);
			JobParameters.Insert("ExclusiveExecution", True);
			JobParameters.Insert("RestartCountOnFailure", 3);
			
			JobQueue.AddJob(JobParameters);
			
			If LockAreas Then
				InfobaseConnections.SetDataAreaSessionLock(LockParameters, False, Selection.DataArea);
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			If BlockSetError Then
				Continue;
			Else
				Raise;
			EndIf;
			
		EndTry;
		
	EndDo;
	
EndProcedure

// Handler of the DataAreasUpdate scheduled job.
// Selects all data areas with
// irrelevant versions and generates background jobs IBUpdate in them if needed.
//
Procedure DataAreasUpdate() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Call OnBeginScheduledJobExecution
	// is not used as required actions are executed privately.
	
	ScheduleDataAreaUpdate(True);
	
EndProcedure

// Returns the record key for the DataAreasSubsystemVersions information register.
//
// Returns: 
//   InformationRegisterRecordKey.
//
Function SubsystemVersionRecordKey() Export
	
	KeyValues = New Structure;
	If CommonUseReUse.CanUseSeparatedData() Then
		KeyValues.Insert("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		KeyValues.Insert("SubsystemName", "");
		RecordKey = SaaSOperations.CreateAuxiliaryDataRecordKeyOfInformationRegister(
			InformationRegisters.DataAreasSubsystemVersions, KeyValues);
	EndIf;
	
	Return RecordKey;
	
EndFunction

// Locks record in the DataAreasSubsystemsVersions information register that corresponds
// to the current data area and returns the key of this record.
//
// Returns: 
//   InformationRegisterRecordKey.
//
Function LockDataAreasVersions() Export
	
	RecordKey = Undefined;
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If CommonUseReUse.CanUseSeparatedData() Then
			SetPrivilegedMode(True);
		EndIf;
		
		RecordKey = SubsystemVersionRecordKey();
		
	EndIf;
	
	If RecordKey <> Undefined Then
		Try
			LockDataForEdit(RecordKey);
		Except
			WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent() + ". " 
				+ NStr("en='Data area updating';ru='Обновление области данных'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
			Raise(NStr("en='An error occurred while updating data area. Record of the data area versions has been locked.';ru='Ошибка обновления области данных. Запись версий области данных заблокирована.'"));
		EndTry;
	EndIf;
	Return RecordKey;
	
EndFunction

// Unlocks the record in the DataAreasSubsystemsVersions information register.
//
// Parameters: 
//   RecordKey - InformationRegisterRecordKey
//
Procedure UnlockDataAreasVersions(RecordKey) Export
	
	If RecordKey <> Undefined Then
		UnlockDataForEdit(RecordKey);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure OnDBVersionDefinition(Val LibraryID, Val GetCommonDataVersion, StandardProcessing, IBVersion) Export
	
	If CommonUse.UseSessionSeparator() AND Not GetCommonDataVersion Then
		
		StandardProcessing = False;
		
		QueryText = 
		"SELECT
		|	DataAreasSubsystemVersions.Version
		|FROM
		|	InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
		|WHERE
		|	DataAreasSubsystemVersions.SubsystemName = &SubsystemName
		|	AND DataAreasSubsystemVersions.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		Query.SetParameter("SubsystemName", LibraryID);
		Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		ValueTable = Query.Execute().Unload();
		IBVersion = "";
		If ValueTable.Count() > 0 Then
			IBVersion = TrimAll(ValueTable[0].Version);
		EndIf;
		
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure OnDetermingFirstEntryInDataArea(StandardProcessing, Result) Export
	
	If CommonUse.UseSessionSeparator() Then
		
		StandardProcessing = False;
		
		QueryText = 
		"SELECT TOP 1
		|	1
		|FROM
		|	InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
		|WHERE
		|	DataAreasSubsystemVersions.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
		Result = Query.Execute().IsEmpty();
		
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure OnDBVersionInstallation(Val LibraryID, Val VersionNumber, StandardProcessing) Export
	
	If CommonUse.UseSessionSeparator() Then
		
		StandardProcessing = False;
		
		DataArea = CommonUse.SessionSeparatorValue();
		
		RecordManager = InformationRegisters.DataAreasSubsystemVersions.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.SubsystemName = LibraryID;
		RecordManager.Version = VersionNumber;
		RecordManager.Write();
		
	EndIf;
	
EndProcedure

// Only for internal use.
Function MinimumVersionOfDataAreas() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		Raise NStr("en='Call of
		|the InfobaseUpdateServiceReUse.MinIBVersion() function is not available from the sessions with the set service model separators value.';ru='Вызов
		|функции ОбновлениеИнформационнойБазыСлужебныйПовтИсп.МинимальнаяВерсияИБ() недоступен из сеансов с установленным значением разделителей модели сервиса!'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SubsystemName", Metadata.Name);
	Query.Text =
	"SELECT DISTINCT
	|	DataAreasSubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
	|WHERE
	|	DataAreasSubsystemVersions.SubsystemName = &SubsystemName";
	
	Selection = Query.Execute().Select();
	
	MinimumIBVersion = Undefined;
	
	While Selection.Next() Do
		If CommonUseClientServer.CompareVersions(Selection.Version, MinimumIBVersion) > 0 Then
			MinimumIBVersion = Selection.Version;
		EndIf
	EndDo;
	
	Return MinimumIBVersion;
	
EndFunction

// Only for internal use.
Procedure SetVersionForAllDataAreas(LibraryID, OriginalVersionOfDB, MetadataIBVersion)
	
	Block = New DataLock;
	Block.Add("InformationRegister.DataAreasSubsystemVersions");
	Block.Add("InformationRegister.DataAreas");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	DataAreas.DataAreaAuxiliaryData AS DataArea
		|FROM
		|	InformationRegister.DataAreas AS DataAreas
		|		INNER JOIN InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
		|		BY DataAreas.DataAreaAuxiliaryData = DataAreasSubsystemVersions.DataAreaAuxiliaryData
		|WHERE
		|	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)
		|	AND DataAreasSubsystemVersions.SubsystemName = &SubsystemName
		|	AND DataAreasSubsystemVersions.Version = &Version";
		Query.SetParameter("SubsystemName", LibraryID);
		Query.SetParameter("Version", OriginalVersionOfDB);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			RecordManager = InformationRegisters.DataAreasSubsystemVersions.CreateRecordManager();
			RecordManager.DataAreaAuxiliaryData = Selection.DataArea;
			RecordManager.SubsystemName = LibraryID;
			RecordManager.Version = MetadataIBVersion;
			RecordManager.Write();
		EndDo;
		
		CommitTransaction();
	Except
		Raise;
		RollbackTransaction();
	EndTry;
	
EndProcedure

#EndRegion
