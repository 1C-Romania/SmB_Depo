////////////////////////////////////////////////////////////////////////////////
// "Full-text search" subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Updates fulltext search index.
Procedure FullTextSearchUpdateIndex() Export
	
	UpdateIndex(NStr("en='Full-text search index updating';ru='Обновление индекса ППД'"), False, True);
	
EndProcedure

// Merges full-text search indexes.
Procedure FullTextSearchIndexMerge() Export
	
	UpdateIndex(NStr("en='Full-text search Index Merging';ru='Слияние индекса ППД'"), True);
	
EndProcedure

// Returns whether full-text search index is relevant.
//   "UseFullTextSearch" functional option is executed in the caller code.
//
Function SearchIndexTrue() Export
	
	Return (
		// Operations
		// are not allowed, or index fully corresponds to
		// the infobase current state, or index was updated less than 5 minutes ago.
		Not OperationsAllowed()
		OR FullTextSearch.IndexTrue()
		OR CurrentDate() < FullTextSearch.UpdateDate() + 300); // Excepion from the SessionCurrentDate() rule.
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"FullTextSearchServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"FullTextSearchServer");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not CommonUse.SubsystemExists("StandardSubsystems.ApplicationSettings")
		Or Not Users.InfobaseUserWithFullAccess()
		Or Not GetFunctionalOption("UseFullTextSearch")
		Or ModuleCurrentWorksService.WorkDisabled("FullTextSearchInData") Then
		Return;
	EndIf;
	
	UpdateDateIndex = FullTextSearch.UpdateDate();
	// Exception, CurrentDate() should be used.
	Interval = CommonUse.TimeIntervalAsString(UpdateDateIndex, CurrentDate());
	// Exception, CurrentDate() should be used.
	DaysSinceLastUpdate = Int((CurrentDate() - UpdateDateIndex)/60/60/24);
	
	Section = Metadata.Subsystems["SetupAndAdministration"];
	IDFullTextSearch = "FullTextSearchInData" + StrReplace(Section.FullName(), ".", "");
	Work = CurrentWorks.Add();
	Work.ID  = IDFullTextSearch;
	Work.ThereIsWork       = (DaysSinceLastUpdate >= 1 AND Not FullTextSearch.IndexTrue());
	Work.Presentation  = NStr("en='Full-text search index is outdated';ru='Индекс полнотекстового поиска устарел'");
	Work.Form          = "DataProcessor.AdministrationPanelSSL.Form.FullTextSearchAndTextsExtractionManagement";
	Work.ToolTip      = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Last update %1 ago';ru='Последнее обновление %1 назад'"), Interval);
	Work.Owner       = Section;
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "FullTextSearchServer.InitializeFunctionalOptionFullTextSearch";
	Handler.Version = "1.0.0.1";
	Handler.SharedData = True;
	
EndProcedure

// Sets constant value FullTextSearchServer.
//   Use for
//   functional option value
//   synchronization "UseFullTextSearch" with "FullTextSearch.GetFullTextSearchMode()".
//
Procedure InitializeFunctionalOptionFullTextSearch() Export
	
	ConstantValue = OperationsAllowed();
	Constants.UseFullTextSearch.Set(ConstantValue);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Scheduled job handler.
Procedure FullTextSearchIndexUpdateOnSchedule() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	FullTextSearchUpdateIndex();
	
EndProcedure

// Scheduled job handler.
Procedure FullTextSearchIndexMergeOnSchedule() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	FullTextSearchIndexMerge();
	
EndProcedure

// General procedure for update and merge FTS index.
Procedure UpdateIndex(ProcedureRepresentation, AllowMerge = False, ByPortions = False)
	
	If Not OperationsAllowed() Then
		Return;
	EndIf;
	
	CommonUse.OnStartExecutingScheduledJob();
	
	LogRecord(Undefined, NStr("en='Launching procedure ""%1"".';ru='Запуск процедуры ""%1"".'"), , ProcedureRepresentation);
	
	Try
		FullTextSearch.UpdateIndex(AllowMerge, ByPortions);
		LogRecord(Undefined, NStr("en='Procedure was successfully complete ""%1"".';ru='Успешное завершение процедуры ""%1"".'"), , ProcedureRepresentation);
	Except
		LogRecord(Undefined, NStr("en='An error occurred while executing procedure ""%1"":';ru='Ошибка выполнения процедуры ""%1"":'"), ErrorInfo(), ProcedureRepresentation);
	EndTry;
	
EndProcedure

// Returns whether full-text search operations are allowed: indexes update, indexes clearing, search.
Function OperationsAllowed() Export
	
	Return FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable;
	
EndFunction

// Creates record in the events log monitor and messages to user;
//   Supports up to 3 parameters in the comment using the function.
//   RowFunctionsClientServerInputParametersToString
//   Supports error information transfer, detailed
//   error presentation is added to the record comment to the events log monitor.
//
// Parameters:
//   JournalLevel - EventLogLevel - Importance of message for the administrator.
//   CommentWithParameters - String - Comment that can contain parameters %1, %2 and %3.
//   ErrorInfo - ErrorInfo, String - Error information that will be posted after the comment.
//   Parameter1 - String - For CommentWithParameters substitution instead of %1.
//   Parameter2 - String - For CommentWithParameters substitution instead of %2.
//   Parameter3 - String - For CommentWithParameters substitution instead of %3.
//
Procedure LogRecord(JournalLevel = Undefined, CommentWithParameters = "",
	ErrorInfo = Undefined,
	Parameter1 = Undefined,
	Parameter2 = Undefined,
	Parameter3 = Undefined)
	
	// Determine events log monitor level according to the passed error message type.
	If TypeOf(JournalLevel) <> Type("EventLogLevel") Then
		If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
			JournalLevel = EventLogLevel.Error;
		ElsIf TypeOf(ErrorInfo) = Type("String") Then
			JournalLevel = EventLogLevel.Warning;
		Else
			JournalLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	// Comment for the events log monitor.
	TextForLog = CommentWithParameters;
	If Parameter1 <> Undefined Then
		TextForLog = StringFunctionsClientServer.SubstituteParametersInString(
			TextForLog, Parameter1, Parameter2, Parameter3);
	EndIf;
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		TextForLog = TextForLog + Chars.LF + DetailErrorDescription(ErrorInfo);
	ElsIf TypeOf(ErrorInfo) = Type("String") Then
		TextForLog = TextForLog + Chars.LF + ErrorInfo;
	EndIf;
	TextForLog = TrimAll(TextForLog);
	
	// Record in the event log.
	WriteLogEvent(
		NStr("en='Full text indexing';ru='Полнотекстовое индексирование'", CommonUseClientServer.MainLanguageCode()), 
		JournalLevel, , , 
		TextForLog);
	
EndProcedure

#EndRegion
