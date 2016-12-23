
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
		
	KeyVar = "";
	For Each Warning IN Parameters.Warnings Do
		KeyVar = KeyVar + Warning.ActionIfMarked.Form + Warning.ActionOnHyperlinkClick.Form;
	EndDo;
	Hash = New DataHashing(HashFunction.MD5);
	Hash.Append(KeyVar);
	WindowOptionsKey = "ExitWarnings" + StrReplace(Hash.HashSum, " ", "");
	
	InitItemsInForm(Parameters.Warnings);
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ClickOnHyperlink(Item)
	ItemName = Item.Name;
	
	For Each QuestionString IN ItemsAndParametersMapArray Do
		QuestionParameters = New Structure("Name, Form, FormParameters");
		
		FillPropertyValues(QuestionParameters, QuestionString.Value);
		If ItemName = QuestionParameters.Name Then 
			
			If QuestionParameters.Form <> Undefined Then
				OpenForm(QuestionParameters.Form, QuestionParameters.FormParameters, ThisObject);
			EndIf;
			
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient 
Procedure CheckboxOnChange(Item)
	
	ItemName      = Item.Name;
	FoundItem = Items.Find(ItemName);
	
	If FoundItem = Undefined Then 
		Return;
	EndIf;
	
	ItemValue = ThisObject[ItemName];
	If TypeOf(ItemValue) <> Type("Boolean") Then
		Return;
	EndIf;

	ArrayID = TaskIDByName(ItemName);
	If ArrayID = Undefined Then 
		Return;
	EndIf;
	
	ArrayElement = TaskArrayToExecuteOnClose.FindByID(ArrayID);
	
	Use = Undefined;
	If ArrayElement.Value.Property("Use", Use) Then 
		If TypeOf(Use) = Type("Boolean") Then 
			ArrayElement.Value.Use = ItemValue;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Complete(Command)
	
	ExecuteTasksOnClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close(True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Creates form items by passed questions to the user.
//
// Parameters:
//     Questions - Array - structure parameters with values issues.
//                       See. StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs
//
&AtServer
Procedure InitItemsInForm(Val Warnings)
	
	// Add the default values probably not listed.
	TableOfNotifications = StructuresArrayToValuesTable(Warnings);
	
	For Each CurrentWarning IN TableOfNotifications Do 
		
		// Add item on the form only if text for the flag is specified or the text for the hyperlink, but not both at the same time.
		NeedRefs = Not IsBlankString(CurrentWarning.HyperlinkText);
		NeedFlag   = Not IsBlankString(CurrentWarning.FlagText);
		
		If NeedRefs AND NeedFlag Then
			Continue;
			
		ElsIf NeedRefs Then
			CreateHyperlinkOnForm(CurrentWarning);
			
		ElsIf NeedFlag Then
			CreateCheckBoxOnForm(CurrentWarning);
			
		EndIf;
		
	EndDo;
	
	// Footer.
	LabelText = NStr("en='Do you want to exit the application?';ru='Завершить работу с программой?'");
	
	LabelName    = FindLabelNameOnForm("QuestionLabel");
	LabelsGroup = GenerateFormItemGroup();
	
	InformationTextItem = Items.Add(LabelName, Type("FormDecoration"), LabelsGroup);
	InformationTextItem.VerticalAlign = ItemVerticalAlign.Bottom;
	InformationTextItem.Title             = LabelText;
	InformationTextItem.Height                = 2;
	
EndProcedure

&AtServer
Function StructuresArrayToValuesTable(Val Warnings)
	
	// Generate a table that contains default values.
	TableOfNotifications = New ValueTable;
	WarningsColumns = TableOfNotifications.Columns;
	WarningsColumns.Add("ExplanationText");
	WarningsColumns.Add("FlagText");
	WarningsColumns.Add("ActionIfMarked");
	WarningsColumns.Add("HyperlinkText");
	WarningsColumns.Add("ActionOnHyperlinkClick");
	WarningsColumns.Add("Priority");
	WarningsColumns.Add("OutputOneMessageBox");
	WarningsColumns.Add("ExtendedTooltip");
	
	SingleWarnings = New Array;
	
	For Each ItemWarnings IN Warnings Do
		TableRow = TableOfNotifications.Add();
		FillPropertyValues(TableRow, ItemWarnings);
		
		If TableRow.OutputOneMessageBox = True Then
			SingleWarnings.Add(TableRow);
		EndIf;
	EndDo;
	
	// If there was at least one warning, which requires cleaning (OutputOneMessageBox = True) then clear the remaining.
	If SingleWarnings.Count() > 0 Then
		TableOfNotifications = TableOfNotifications.Copy(SingleWarnings);
	EndIf;
	
	// The higher the priority, the higher in the list a warning is displayed.
	TableOfNotifications.Sort("Priority DESC");
	
	Return TableOfNotifications;
EndFunction

&AtServer
Function GenerateFormItemGroup()
	
	GroupName = FindLabelNameOnForm("GroupOnForm");
	
	Group = Items.Add(GroupName, Type("FormGroup"), Items.MainGroup);
	Group.Type = FormGroupType.UsualGroup;
	
	Group.HorizontalStretch = True;
	Group.ShowTitle      = False;
	Group.Representation              = UsualGroupRepresentation.None;
	
	Return Group; 
	
EndFunction

&AtServer
Procedure CreateHyperlinkOnForm(QuestionStructure)
	
	Group = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.ExplanationText) Then 
		LabelName = FindLabelNameOnForm("QuestionLabel");
		LabelType = Type("FormDecoration");
		
		LabelParent = Group;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.ExplanationText;
	EndIf;
	
	If IsBlankString(QuestionStructure.HyperlinkText) Then
		Return;
	EndIf;
	
	// Construct a hyperlink
	HyperlinkName = FindLabelNameOnForm("QuestionLabel");
	HyperlinkType = Type("FormDecoration");
	
	HyperlinkParent = Group;

	HyperlinkItem = Items.Add(HyperlinkName, HyperlinkType, HyperlinkParent);
	HyperlinkItem.Hyperlink = True;
	HyperlinkItem.Title   = QuestionStructure.HyperlinkText;
	HyperlinkItem.SetAction("Click", "ClickOnHyperlink");
	
	SetExtendededToolTip(HyperlinkItem, QuestionStructure);
	
	DataProcessorStructure = QuestionStructure.ActionOnHyperlinkClick;
	If IsBlankString(DataProcessorStructure.Form) Then
		Return;
	EndIf;
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", HyperlinkName);
	FormOpenParameters.Insert("Form", DataProcessorStructure.Form);
	
	FormParameters = DataProcessorStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ExitApplication", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	ItemsAndParametersMapArray.Add(FormOpenParameters);
		
EndProcedure

&AtServer
Procedure CreateCheckBoxOnForm(QuestionStructure)
	
	DefaultValue = True;
	Group  = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.ExplanationText) Then
		LabelName = FindLabelNameOnForm("QuestionLabel");
		LabelType = Type("FormDecoration");
		
		LabelParent = Group;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.ExplanationText;
	EndIf;
	
	If IsBlankString(QuestionStructure.FlagText) Then 
		Return;
	EndIf;
	
	// Add attribute to the form.
	FlagName = FindLabelNameOnForm("QuestionLabel");
	FlagType = Type("FormField");
	
	FlagParent = Group;
	
	TypeArray = New Array;
	TypeArray.Add(Type("Boolean"));
	Definition = New TypeDescription(TypeArray);
	
	AttributesToAdd = New Array;
	NewAttribute = New FormAttribute(FlagName, Definition, , FlagName, False);
	AttributesToAdd.Add(NewAttribute);
	ChangeAttributes(AttributesToAdd);
	ThisObject[FlagName] = DefaultValue;
	
	NewFormField = Items.Add(FlagName, FlagType, FlagParent);
	NewFormField.DataPath = FlagName;
	
	NewFormField.TitleLocation = FormItemTitleLocation.Right;
	NewFormField.Title         = QuestionStructure.FlagText;
	NewFormField.Type          = FormFieldType.CheckBoxField;
	
	SetExtendededToolTip(NewFormField, QuestionStructure);
	
	If IsBlankString(QuestionStructure.ActionIfMarked.Form) Then
		Return;	
	EndIf;
	
	ActionStructure = QuestionStructure.ActionIfMarked;
	
	NewFormField.SetAction("OnChange", "CheckboxOnChange");
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", FlagName);
	FormOpenParameters.Insert("Form", ActionStructure.Form);
	FormOpenParameters.Insert("Use", DefaultValue);
	
	FormParameters = ActionStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ExitApplication", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	TaskArrayToExecuteOnClose.Add(FormOpenParameters);
	
EndProcedure

&AtServer
Procedure SetExtendededToolTip(FormItem, Val DescriptionString)
	
	ExtendedTooltipDescription = DescriptionString.ExtendedTooltip;
	If ExtendedTooltipDescription = "" Then
		Return;
	EndIf;
	
	If TypeOf(ExtendedTooltipDescription) <> Type("String") Then
		// Set in the extended tooltip.
		FillPropertyValues(FormItem.ExtendedTooltip, ExtendedTooltipDescription);
		FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
		Return;
	EndIf;
	
	FormItem.ExtendedTooltip.Title = ExtendedTooltipDescription;
	FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
	
EndProcedure

&AtServer
Function FindLabelNameOnForm(ItemTitle)
	IndexOf = 0;
	SearchFlag = True;
	
	While SearchFlag Do 
		RowIndex = String(Format(IndexOf, "NZ=-"));
		RowIndex = StrReplace(RowIndex, "-", "");
		Name = ItemTitle + RowIndex;
		
		FoundItem = Items.Find(Name);
		If FoundItem = Undefined Then 
			Return Name;
		EndIf;
		
		IndexOf = IndexOf + 1;
	EndDo;
EndFunction	

&AtClient
Function TaskIDByName(ItemName)
	For Each ArrayElement IN TaskArrayToExecuteOnClose Do
		Description = "";
		If ArrayElement.Value.Property("Name", Description) Then 
			If Not IsBlankString(Description) AND Description = ItemName Then
				Return ArrayElement.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteTasksOnClose(Result = Undefined, TaskStartingNumber = Undefined) Export
	
	If TaskStartingNumber = Undefined Then
		TaskStartingNumber = 0;
	EndIf;
	
	For NumberOfTask = TaskStartingNumber To TaskArrayToExecuteOnClose.Count() - 1 Do
		
		ArrayElement = TaskArrayToExecuteOnClose[NumberOfTask];
		Use = Undefined;
		If Not ArrayElement.Value.Property("Use", Use) Then 
			Continue;
		EndIf;
		If TypeOf(Use) <> Type("Boolean") Then 
			Continue;
		EndIf;
		If Use <> True Then 
			Continue;
		EndIf;
		
		Form = Undefined;
		If ArrayElement.Value.Property("Form", Form) Then 
			FormParameters = Undefined;
			If ArrayElement.Value.Property("FormParameters", FormParameters) Then 
				Notification = New NotifyDescription("ExecuteTasksOnClose", ThisObject, NumberOfTask + 1);
				OpenForm(Form, StructureOfFixedStructure(FormParameters),,,,,Notification, FormWindowOpeningMode.LockOwnerWindow);
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	Close(False);
	
EndProcedure

&AtClient
Function StructureOfFixedStructure(Source)
	
	Result = New Structure;
	
	For Each Item IN Source Do
		Result.Insert(Item.Key, Item.Value);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion














