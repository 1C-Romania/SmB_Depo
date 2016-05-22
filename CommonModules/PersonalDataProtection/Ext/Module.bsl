////////////////////////////////////////////////////////////////////////////////
// Subsystem "Personal data protection".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure prepares system settings
// forms for managing the areas
// of personal data, and also reads the current state "Access" events usage. "Access".
//
// The following objects should be created in the form::
// - an attribute of value tree type, the name of which is - "PersonalDataAreas",
// - table of form that is related to the attribute the name of which is also - "PersonalDataAreas",
//
// Parameters:
// Form - system setting form.
//
Procedure OnEventsRegistrationSettingsFormCreation(Form) Export
	
	If Not SettingFormPreparedCorrect(Form) Then
		Return;
	EndIf;
	
	AreasTreeName = AreasTreeAttributeName();
	
	// Adding the columns of the "PersonalDataArea" attribute.
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute("Use", New TypeDescription("Boolean"), AreasTreeName));
	AttributesToAdd.Add(New FormAttribute("Name", New TypeDescription("String"), AreasTreeName));
	AttributesToAdd.Add(New FormAttribute("Presentation", New TypeDescription("String"), AreasTreeName));
	
	Form.ChangeAttributes(AttributesToAdd);
	
	// Add form fields
	FieldsGroup = Form.Items.Add(AreasTreeName + "GroupUsing", Type("FormGroup"), Form.Items[AreasTreeName]);
	FieldsGroup.Group = ColumnsGroup.InCell;
	
	CheckboxUsing = Form.Items.Add(AreasTreeName + "Use", Type("FormField"), FieldsGroup);
	CheckboxUsing.DataPath = AreasTreeName + ".Use";
	CheckboxUsing.Type= FormFieldType.CheckBoxField;
	
	FieldPresentation = Form.Items.Add(AreasTreeName + "Presentation", Type("FormField"), FieldsGroup);
	FieldPresentation.DataPath = AreasTreeName + ".Presentation";
	FieldPresentation.Type= FormFieldType.LabelField;
	
	// Setting management items.
	Form.Items[AreasTreeName].CommandBarLocation = FormItemCommandBarLabelLocation.None;
	Form.Items[AreasTreeName].ChangeRowSet = False;
	Form.Items[AreasTreeName].ChangeRowOrder = False;
	Form.Items[AreasTreeName].Header = False;
	Form.Items[AreasTreeName].InitialTreeView = InitialTreeView.ExpandAllLevels;
	Form.Items[AreasTreeName].HorizontalLines = False;
	Form.Items[AreasTreeName].VerticalLines = False;
	Form.Items[AreasTreeName].RowSelectionMode = TableRowSelectionMode.Row;
	
	ValueToFormData(GetEventUsageAccess(), Form[AreasTreeName]);
	
EndProcedure

// Procedure transforms data of the
// system setting form and sets the usage of the access events for marked areas.
//
// The following objects should be created in the form::
// - an attribute of value tree type, the name of which is - "PersonalDataAreas",
// - table of form that is related to the attribute the name of which is also - "PersonalDataAreas",
//
// Parameters:
// Form - system setting form.
//
Procedure OnEventsRegistrationSettingsFormWrite(Form) Export
	
	If Not SettingFormPreparedCorrect(Form) Then
		Return;
	EndIf;
	
	AreasTree = FormDataToValue(Form[AreasTreeAttributeName()], Type("ValueTree"));
	
	UsingAreas = New Array;
	
	MarkedRows = AreasTree.Rows.FindRows(New Structure("Use", True), True);
	For Each MarkedRow IN MarkedRows Do
		UsingAreas.Add(MarkedRow.Name);
	EndDo;
	
	SetEventUsageAccess(UsingAreas.Count() > 0, UsingAreas);
	
EndProcedure

// Procedure sets the mode of using the "Access" events. "Access"
// events log control of which is provided for by the requirements.
// Federal law from 27.07.2006 N152-FZ "On personal data" and regulations.
// Event usage is set for personal data fields information about which is filled out in the consumer.
//
// Parameters:
// 	Use - Boolean if True - events will be registered.
// 	UsingAreas - an array of fields of personal data for which the usage is enabled (optional).
//
Procedure SetEventUsageAccess(Use, UsingAreas = Undefined) Export
	
	// Table of personal data information.
	InfoTable = InfoAboutPersonalData();
	
	DataAreasUsing = New Map;
	
	// Making the description of event usage.
	UsageInfo = New Array;
	For Each InformationRow IN InfoTable Do
		// Adding the data area into the set.
		DataAreasUsing.Insert(InformationRow.DataArea);
		If UsingAreas <> Undefined 
			AND UsingAreas.Find(InformationRow.DataArea) = Undefined Then
			// If data areas are specified, then only they will be used.
			Continue;
		EndIf;
		DataAreasUsing[InformationRow.DataArea] = Use;
		// Making the description of event usage.
		LoggedFields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(InformationRow.LoggedFields);
		For IndexOf = 0 To LoggedFields.UBound() Do
			// If required to compose the array of fields.
			If Find(LoggedFields[IndexOf], "|") > 0 Then
				LoggedFields[IndexOf] = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LoggedFields[IndexOf], "|");
			EndIf;
		EndDo;
		AccessEventUsageDetails = New EventLogAccessEventUseDescription(InformationRow.Object);
		AccessEventUsageDetails.AccessFields		= StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(InformationRow.AccessFields);
		AccessEventUsageDetails.LoggedFields	= LoggedFields;
		UsageInfo.Add(AccessEventUsageDetails);
	EndDo;
	
	// WithEnabling ("Disabling") of the "Access" event usage. "Access" 
	// event log according to created description.
	UseAccessEvent = New EventLogEventUse;
	UseAccessEvent.Use = Use;
	UseAccessEvent.UseDescription = UsageInfo;
	
	// Saving the data area usage.
	DataAreasRecordSet = InformationRegisters.PersonalDataAreas.CreateRecordSet();
	For Each KeyAndValue IN DataAreasUsing Do
		SetRow = DataAreasRecordSet.Add();
		SetRow.AreaName = KeyAndValue.Key;
		SetRow.UseRegistrationEventLogMonitor = KeyAndValue.Value;
	EndDo;
	
	BeginTransaction();
	Try
		SetEventLogEventUse("_$Access$_.Access", UseAccessEvent);
		// Recording personal data areas.
		DataAreasRecordSet.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Function creates the tree of used personal data areas.
//
// Parameters:
// 	no
//
// Return
// 	value Value tree - data areas tree with columns:
// 		Name - String, identifier of personal data area.
// 		Presentation - String, user presentation of the data area.
// 		Use - Boolean, flag showing that the
// 				"Access" event registration is enabled for the data area. "Access".
//
Function GetEventUsageAccess() Export
	
	// Creation of areas tree
	DataAreasTree = PersonalDataAreasTree();
	
	// Placement of marks of register data use.
	DataAreasRecordSet = InformationRegisters.PersonalDataAreas.CreateRecordSet();
	DataAreasRecordSet.Read();
	
	For Each SetRow IN DataAreasRecordSet Do
		TreeRow = DataAreasTree.Rows.Find(SetRow.AreaName, "Name", True);
		If TreeRow <> Undefined Then
			TreeRow.Use = SetRow.UseRegistrationEventLogMonitor;
		EndIf;
	EndDo;

	Return DataAreasTree;
	
EndFunction

// Procedure is intended to use the AddPrintCommands method of the standard Print subsystem in the objects that are the subjects of personal data.
// Adds to the list of the printing commands a command of transition to prepare the consent for processing the personal data of a person.
//
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddConsentToPersonalDataProcessingPrintCommand(PrintCommands) Export
	
	If Not Users.RolesAvailable("PersonalDataProcessingConsentPreparation") Then
		Return;
	EndIf; 
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "PersonalDataProcessingConsent";
	PrintCommand.Presentation = NStr("en = 'Personal data processing consent...'");
	PrintCommand.Handler = "PersonalDataProtectionClient.OpenPersonalDataProcessingConsentForm";
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function InfoAboutPersonalData()
	
	// Table of personal data information.
	InfoTable = New ValueTable;
	InfoTable.Columns.Add("Object", 			New TypeDescription("String"));
	InfoTable.Columns.Add("LoggedFields", New TypeDescription("String"));
	InfoTable.Columns.Add("AccessFields", 	New TypeDescription("String"));
	InfoTable.Columns.Add("DataArea", 	New TypeDescription("String"));
	
	// Filling consumers information table.
	PersonalDataProtectionOverridable.FillInfoAboutPersonalData(InfoTable);

	Return InfoTable;
	
EndFunction

Function PersonalDataAreas()
	
	// Match of the areas IDs and their user presentations.
	DataAreas = New ValueTable;
	DataAreas.Columns.Add("Name", 			New TypeDescription("String"));
	DataAreas.Columns.Add("Presentation", New TypeDescription("String"));
	DataAreas.Columns.Add("Parent", 		New TypeDescription("String"));
	
	// Filling the areas with consumers.
	PersonalDataProtectionOverridable.FillPersonalDataAreas(DataAreas);
	
	Return DataAreas;
	
EndFunction

Function SettingFormPreparedCorrect(Form)
	
	AreasTreeName = AreasTreeAttributeName();
	
	// Search for form attribute
	AreasTreeFormAttribute = Undefined;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute IN FormAttributes Do
		If FormAttribute.Name = AreasTreeName Then
			AreasTreeFormAttribute = FormAttribute;
			Break;
		EndIf;
	EndDo;
	
	If AreasTreeFormAttribute = Undefined 
		Or Form.Items.Find(AreasTreeName) = Undefined Then
		// Attribute for areas tree is not found in the form.
		Return False;
	EndIf;

	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with personal data areas tree.
//

Function AreasTreeAttributeName()
	Return "PersonalDataAreas";
EndFunction

Function PersonalDataAreasTree()
	
	DataAreasTree = New ValueTree;
	DataAreasTree.Columns.Add("Use", New TypeDescription("Boolean"));
	DataAreasTree.Columns.Add("Name", New TypeDescription("String"));
	DataAreasTree.Columns.Add("Presentation", New TypeDescription("String"));
	
	DataAreas = PersonalDataAreas();
	
	// Filling the areas tree
	For Each DataArea IN DataAreas Do
		AddDataAreaIntoTree(DataAreasTree, DataAreas, DataArea);
	EndDo;
	
	// If the data areas are not defined for all information or for separate - add data area by default.
	InfoTable = InfoAboutPersonalData();
	If DataAreas.Count() = 0 
		Or InfoTable.FindRows(New Structure("DataArea", "")).Count() > 0 Then
		AddDataAreaIntoTree(DataAreasTree, DataAreas, New Structure("Name, Presentation, Parent", "", NStr("en = 'Personal data'")));
	EndIf;
	
	Return DataAreasTree;
	
EndFunction

Function AddDataAreaIntoTree(AreasTree, DataAreas, DataArea)
	
	// Search for area in the values tree.
	FoundArea = AreasTree.Rows.Find(DataArea.Name, "Name", True);
	If FoundArea <> Undefined Then
		Return FoundArea;
	EndIf;
	
	// Addition to the "root" of the tree.
	Parent = AreasTree;
	If ValueIsFilled(DataArea.Parent) Then
		AreaParent = DataAreas.Find(DataArea.Parent, "Name");
		If AreaParent <> Undefined Then
			Parent = AddDataAreaIntoTree(AreasTree, DataAreas, AreaParent);
		EndIf;
	EndIf;
	
	// Adding the area
	NewArea = Parent.Rows.Add();
	NewArea.Name = DataArea.Name;
	NewArea.Presentation = DataArea.Presentation;
	
	Return NewArea;
	
EndFunction

#EndRegion
