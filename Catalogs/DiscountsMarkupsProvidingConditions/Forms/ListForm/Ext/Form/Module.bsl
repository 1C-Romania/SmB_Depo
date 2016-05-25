# Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;

	ConditionsList = New ValueList;
	
	ConditionsList = DiscountsMarkupsServerOverridable.GetDiscountProvidingConditionsValuesList();
	
	MetadataEnumerationValues = Metadata.Enums.DiscountsMarkupsProvidingConditions.EnumValues;
	EnumerationManager           = Enums.DiscountsMarkupsProvidingConditions;
	
	For Each ItemOfList IN ConditionsList Do
		
		EnumerationName = MetadataEnumerationValues[EnumerationManager.IndexOf(ItemOfList.Value)].Name;
		
		control = Items.Find("CommandCreate" + EnumerationName);
		If Not control = Undefined Then
		
			control.Visible = True;
		
		EndIf;
		
	EndDo;
	
	// Handler of the Additional reports and data processors subsystem
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure

#EndRegion

# Region FormCommandsHandlers

// Procedure - handler of the CommandCreateForPurchaseKit form command.
//
&AtClient
Procedure CreateCommandForKitPurchase(Command)
	
	CommandCreateCondition(Command)
	
EndProcedure

// Procedure - handler of the CommandCreateForOneTimeSalesVolume form command.
//
&AtClient
Procedure CreateCommandForOneTimeSalesVolume(Command)
	
	CommandCreateCondition(Command)
	
EndProcedure

// Procedure - handler of the CommandCreateForPurchaseKit and CommandCreateForOneTimeSalesVolume form commands.
//
&AtClient
Procedure CommandCreateCondition(Command)

	CommandName      = Command.Name;
	EnumerationName = StrReplace(CommandName, "CommandCreate", "");
	
	ParameterStructure = New Structure;
	BaseStructure = New Structure;
	BaseStructure.Insert("AssignmentCondition", PredefinedValue("Enumeration.DiscountsMarkupsProvidingConditions." + EnumerationName));
	CurrentListRow = Items.List.CurrentData;
	If CurrentListRow <> Undefined Then
		CurrentParent = CurrentGroupInList(CurrentListRow.Ref);
		BaseStructure.Insert("Parent", CurrentParent);
	EndIf;
	ParameterStructure.Insert("Basis", BaseStructure);
	OpenForm("Catalog.DiscountsMarkupsProvidingConditions.Form.ItemForm", ParameterStructure);

EndProcedure

#EndRegion

# Region ServiceProceduresAndFunctions

// Function specifies the parent of a new condition. If group is selected, it is transferred as a parent. If element, then its parent.
//
&AtServer
Function CurrentGroupInList(CurrentRef)
	
	CurrentGroup = Undefined;
	
	CurrentRefAttributes = CommonUse.ObjectAttributesValues(CurrentRef, New Structure("IsFolder, Parent"));
	If CurrentRefAttributes.IsFolder Then
		CurrentGroup = CurrentRef;
	Else
		CurrentGroup = CurrentRefAttributes.Parent;
	EndIf;
	
	Return CurrentGroup;
	
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
