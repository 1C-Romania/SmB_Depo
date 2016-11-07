////////////////////////////////////////////////////////////////////////////////
// The Current ToDos subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Announces service events of the CurrentWorks subsystem.
//
// Server events:
//   AtFillingToDoList.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Fills the user current work list.
	//
	// Parameters:
	//  CurrentWorks - ValueTable - a table of values with the following columns:
	//    External ID - String - an internal work identifier used by the Current Work mechanism.
	//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
	//    Commands group important        - Boolean - If True, the work is marked in red.
	//    * Presentation String - a work presentation displayed to the user.
	//    * Count Number  - a quantitative indicator of work, it is displayed in the work header string.
	//    •  For the Inventory writing off  document a print form is added         - String - the complete path to the form which you need
	//                               to open at clicking the work hyperlink on the Current Work bar.
	//    * FormParameters- Structure - the parameters to be used to open the indicator form.
	//    * Owner String, metadata object - a string identifier of the work, which
	//                      will be the owner for the current work or a subsystem metadata object.
	//    * ToolTip String - The tooltip wording.
	//
	// Syntax:
	// Procedure AtFillingToDoList (CurrentWorks) Export
	//
	ServerEvents.Add("StandardSubsystems.CurrentWorks\AtFillingToDoList");
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  StorageAddress - String - address of the temporary storage
//                            where the result of function performing will be placed.
//                            If it is not set, the values are returned to the table.
//
// Returns:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    External ID - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    Commands group important        - Boolean - If True, the work is marked in red.
//    * Presentation String - a work presentation displayed to the user.
//    * Count Number  - a quantitative indicator of work, it is displayed in the work header string.
//    •  For the Inventory writing off  document a print form is added         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip String - The tooltip wording.
//
Function UserToDoList(StorageAddress, ClientParametersOnServer = Undefined) Export
	
	// Forwarding client parameters to the background job.
	If ClientParametersOnServer <> Undefined Then
		SetPrivilegedMode(True);
		SessionParameters.ClientParametersOnServer = ClientParametersOnServer;
		SetPrivilegedMode(False);
	EndIf;
	
	CurrentWorks = NewCurrentWorksTable();
	
	// Filling SSL current work.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.CurrentWorks\AtFillingToDoList");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.AtFillingToDoList(CurrentWorks);
	EndDo;
	
	// Adding works from applied configurations.
	WorkFillHandlers = New Array;
	CurrentWorksOverridable.AtDeterminingCurrentWorksHandlers(WorkFillHandlers);
	
	For Each Handler IN WorkFillHandlers Do
		Handler.AtFillingToDoList(CurrentWorks);
	EndDo;
	
	// Result postprocessing.
	ConvertCurrentWorksTable(CurrentWorks);
	
	PutToTempStorage(CurrentWorks, StorageAddress);
	
EndFunction

// Returns structure of saved settings
// of work display for the current user.
//
Function SavedDisplaySettings() Export
	
	DisplaySettings = CommonSettingsStorage.Load("CurrentWorks", "DisplaySettings");
	If DisplaySettings = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(DisplaySettings) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If DisplaySettings.Property("WorkTree")
		AND DisplaySettings.Property("SectionsVisible")
		AND DisplaySettings.Property("WorkVisible") Then
		Return DisplaySettings;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Gets numeric values of work from the transferred query.
//
// A query with data should contain only one string with an arbitrary number of fields.
// Values of these fields shall be the values of the corresponding  indicators.
//
// Example of a simple query:
// SELECT
// 	Count(*) AS <Name of the predefined item - documents quantity indicator>.
// FROM
// 	Document.<Document name>
//
// Parameters:
//  Query - running query.
//  CommonQueryParameters - Structure - general values for calculation of current works.
//
Function CurrentWorksNumericIndicators(Query, CommonQueryParameters = Undefined) Export
	
	// Set general parameters for all queries.
	// Specific parameters of this query if any, shall be specified earlier.
	If Not CommonQueryParameters = Undefined Then
		SetCommonQueryParameters(Query, CommonQueryParameters);
	EndIf;
	
	Result = Query.ExecuteBatch();
	
	PackageQueriesNumbers = New Array;
	PackageQueriesNumbers.Add(Result.Count() - 1);
	
	// Choose all queries with data.
	QueryResult = New Structure;
	For Each QueryNumber IN PackageQueriesNumbers Do
		
		Selection = Result[QueryNumber].Select();
		
		If Selection.Next() Then
			
			For Each Column IN Result[QueryNumber].Columns Do
				WorkValue = ?(TypeOf(Selection[Column.Name]) = Type("Null"), 0, Selection[Column.Name]);
				QueryResult.Insert(Column.Name, WorkValue);
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return QueryResult;
	
EndFunction

// Returns the structure of general values used for calculation of current work.
//
// Returns:
//  Structure - the value name and the value itself.
//
Function CommonQueryParameters() Export
	
	CommonQueryParameters = New Structure;
	CommonQueryParameters.Insert("User", UsersClientServer.CurrentUser());
	CommonQueryParameters.Insert("InfobaseUserWithFullAccess", Users.InfobaseUserWithFullAccess());
	CommonQueryParameters.Insert("CurrentDate", CurrentSessionDate());
	CommonQueryParameters.Insert("BlankDate", '00010101000000');
	
	Return CommonQueryParameters;
	
EndFunction

// Sets general parameters of queries for current works calculation.
//
// Parameters:
//  Query - running query.
//  CommonQueryParameters - Structure - common values for calculation of indicators.
//
Procedure SetCommonQueryParameters(Query, CommonQueryParameters) Export
	
	For Each KeyAndValue IN CommonQueryParameters Do
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	CurrentWorksOverridable.SetCommonQueryParameters(Query, CommonQueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
//
Procedure ConvertCurrentWorksTable(CurrentWorks)
	
	CurrentWorks.Columns.Add("IDOwner", New TypeDescription("String", New StringQualifiers(250)));
	CurrentWorks.Columns.Add("ThisIsSection", New TypeDescription("Boolean"));
	CurrentWorks.Columns.Add("PresentationOfSection", New TypeDescription("String", New StringQualifiers(250)));
	
	ControllableWorks = New Array;
	For Each Work IN CurrentWorks Do
		
		If TypeOf(Work.Owner) = Type("MetadataObject") Then
			SectionAvailable = CommonUse.MetadataObjectAvailableByFunctionalOptions(Work.Owner);
			If Not SectionAvailable Then
				ControllableWorks.Add(Work);
				Continue;
			EndIf;
			
			Work.IDOwner = StrReplace(Work.Owner.FullName(), ".", "");
			Work.ThisIsSection              = True;
			Work.PresentationOfSection   = Work.Owner.Synonym;
		Else
			ThisIsWorkIdentifier = (CurrentWorks.Find(Work.Owner, "ID") <> Undefined);
			If ThisIsWorkIdentifier Then
				Work.IDOwner = Work.Owner;
			Else
				Work.IDOwner = StrReplace(Work.Owner, " ", "");
				Work.ThisIsSection              = True;
				Work.PresentationOfSection   = Work.Owner;
			EndIf;
		EndIf;
		
	EndDo;
	
	For Each ControllableWork IN ControllableWorks Do
		CurrentWorks.Delete(ControllableWork);
	EndDo;
	
	CurrentWorks.Columns.Delete("Owner");
	
EndProcedure

// Creates an empty user work table.
//
// Returns:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    External ID - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    Commands group important        - Boolean - If True, the work is marked in red.
//    * Presentation String - a work presentation displayed to the user.
//    * Count Number  - a quantitative indicator of work, it is displayed in the work header string.
//    •  For the Inventory writing off  document a print form is added         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner String, metadata object -
//                               MetadataObject: Subsystem - the command interface subsystem,
//                                                              in which this work will be placed.
//                               String - identifier of a
//                                        top level work, it is required to specify owner of a subsidiary work  (description of the top level work).
//    * ToolTip String - The tooltip wording.
//
Function NewCurrentWorksTable()
	
	UserWorks = New ValueTable;
	UserWorks.Columns.Add("ID", New TypeDescription("String", New StringQualifiers(250)));
	UserWorks.Columns.Add("ThereIsWork", New TypeDescription("Boolean"));
	UserWorks.Columns.Add("Important", New TypeDescription("Boolean"));
	UserWorks.Columns.Add("Presentation", New TypeDescription("String", New StringQualifiers(250)));
	UserWorks.Columns.Add("Count", New TypeDescription("Number"));
	UserWorks.Columns.Add("Form", New TypeDescription("String", New StringQualifiers(250)));
	UserWorks.Columns.Add("FormParameters", New TypeDescription("Structure"));
	UserWorks.Columns.Add("Owner");
	UserWorks.Columns.Add("ToolTip", New TypeDescription("String", New StringQualifiers(250)));
	
	Return UserWorks;
	
EndFunction

// Only for internal use.
//
Function WorkDisabled(WorkIdentifier) Export
	DisabledWork = New Array;
	CurrentWorksOverridable.AtCurrentWorksDisable(DisabledWork);
	
	Return (DisabledWork.Find(WorkIdentifier) <> Undefined)
	
EndFunction

#EndRegion
