#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeOfStructuralUnitRetail = Enums.StructuralUnitsTypes.Retail;
	TypeOfStructuralUnitRetailAmmountAccounting = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	TypeOfStructuralUnitWarehouse = Enums.StructuralUnitsTypes.Warehouse;
	
	Items.OrderWarehouse.Enabled = Object.StructuralUnitType = TypeOfStructuralUnitWarehouse;
	Items.RetailPriceKind.Visible = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
	);
	
	If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get()
	 OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Warehouse);
		If Constants.FunctionalOptionAccountingRetail.Get() 
			OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Retail 
			OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Retail);
			Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
		EndIf;
	EndIf;
	
	If Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Department Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Department);
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		  AND Items.StructuralUnitType.ChoiceList.Count() = 1 Then
		Object.StructuralUnitType = Items.StructuralUnitType.ChoiceList[0].Value;
	EndIf;
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Items.Company.Visible = False;
	EndIf;
	
	Items.RetailPriceKind.Enabled = Not Object.OrderWarehouse;
	Items.RetailPriceKind.AutoMarkIncomplete = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
	);
	
	If Parameters.Key.IsEmpty() Then
		// SB.ContactInformation
		ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
		// End SB.ContactInformation
	КонецЕсли;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	// SB.ContactInformation
	ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
	// End SB.ContactInformation
	
EndProcedure // OnReadAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
	If EventName = "AccountsChangedStructuralUnits" Then
		Object.GLAccountInRetail = Parameter.GLAccountInRetail;
		Object.MarkupGLAccount = Parameter.MarkupGLAccount;
		Modified = True;
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
		
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
	// SB.ContactInformation
	ContactInformationSB.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End SB.ContactInformation
	
EndProcedure // BeforeWriteAtServer()

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	// SB.ContactInformation
	ContactInformationSB.FillCheckProcessingAtServer(ThisObject, Cancel);
	// End SB.ContactInformation
	
EndProcedure // FillCheckProcessingAtServer()

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure // AfterWriteOnServer()

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure StructuralUnitTypeOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitType) Then
		
		If Object.StructuralUnitType = TypeOfStructuralUnitWarehouse Then
			Items.OrderWarehouse.Enabled = True;
		Else
			Items.OrderWarehouse.Enabled = False;
			Object.OrderWarehouse = False;
		EndIf;
		
		Items.RetailPriceKind.Visible = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
		);
		
		Items.RetailPriceKind.MarkIncomplete = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
		);
		
	Else
		
		Items.OrderWarehouse.Enabled = False;
		Object.OrderWarehouse = False;
		
	EndIf;
	
EndProcedure // StructuralUnitTypeOnChange()

&AtClient
Procedure InventoryAutotransferClick(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("TransferSource", Object.TransferSource);
	ParametersStructure.Insert("TransferRecipient", Object.TransferRecipient);
	ParametersStructure.Insert("RecipientOfWastes", Object.RecipientOfWastes);
	ParametersStructure.Insert("WriteOffToExpensesSource", Object.WriteOffToExpensesSource);
	ParametersStructure.Insert("WriteOffToExpensesRecipient", Object.WriteOffToExpensesRecipient);
	ParametersStructure.Insert("PassToOperationSource", Object.PassToOperationSource);
	ParametersStructure.Insert("PassToOperationRecipient", Object.PassToOperationRecipient);
	ParametersStructure.Insert("ReturnFromOperationSource", Object.ReturnFromOperationSource);
	ParametersStructure.Insert("ReturnFromOperationRecipient", Object.ReturnFromOperationRecipient);
	
	ParametersStructure.Insert("TransferSourceCell", Object.TransferSourceCell);
	ParametersStructure.Insert("TransferRecipientCell", Object.TransferRecipientCell);
	ParametersStructure.Insert("DisposalsRecipientCell", Object.DisposalsRecipientCell);
	ParametersStructure.Insert("WriteOffToExpensesSourceCell", Object.WriteOffToExpensesSourceCell);
	ParametersStructure.Insert("WriteOffToExpensesRecipientCell", Object.WriteOffToExpensesRecipientCell);
	ParametersStructure.Insert("PassToOperationSourceCell", Object.PassToOperationSourceCell);
	ParametersStructure.Insert("PassToOperationRecipientCell", Object.PassToOperationRecipientCell);
	ParametersStructure.Insert("ReturnFromOperationSourceCell", Object.ReturnFromOperationSourceCell);
	ParametersStructure.Insert("ReturnFromOperationRecipientCell", Object.ReturnFromOperationRecipientCell);
	
	ParametersStructure.Insert("StructuralUnitType", Object.StructuralUnitType);
	
	Notification = New NotifyDescription("AutomovementocksEndClick",ThisForm);
	OpenForm("CommonForm.AutoTransferInventoryForm", ParametersStructure,,,,,Notification);
	
	
EndProcedure // InventoryAutotransferClick()

&AtClient
Procedure RetailPriceKindOnChange(Item)
	
	If Not ValueIsFilled(Object.RetailPriceKind) Then
		Return;
	EndIf;
	
	DataStructure = GetRetailPriceKindData(Object.RetailPriceKind);
	
	If Not DataStructure.PriceCurrency = DataStructure.NationalCurrency Then
		
		MessageText = NStr("en='Specify national currency (%NatCurrency%) for the ""%PricesKind%"" price kind for retail structural unit.';ru='У вида цен ""%ВидЦен%"", для розничной структурной единицы, должна быть задана национальная валюта (%НацВалюта%).'");
		MessageText = StrReplace(MessageText, "%PriceKind%", DataStructure.PriceKindDescription);
		MessageText = StrReplace(MessageText, "%NatCurrency%", DataStructure.NationalCurrency);
		
		CommonUseClientServer.MessageToUser(MessageText, , "Object.RetailPriceKind");
		
		Object.RetailPriceKind = Undefined;
		
	EndIf;
	
EndProcedure //RetailPriceKindOnChange()

&AtClient
Procedure OrderWarehouseOnChange(Item)
	
	Items.RetailPriceKind.Enabled = Not Object.OrderWarehouse;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function GetRetailPriceKindData(RetailPriceKind)
	
	DataStructure	 = New Structure;
	
	DataStructure.Insert("PriceKindDescription",	RetailPriceKind.Description);
	DataStructure.Insert("NationalCurrency",	Constants.NationalCurrency.Get());
	DataStructure.Insert("PriceCurrency", 			RetailPriceKind.PriceCurrency);
	
	Return DataStructure;
	
EndFunction //GetRetailPriceKindData()

&AtClient
Procedure AutomovementocksEndClick(FillingParameters,Parameters) Export
	
	If TypeOf(FillingParameters) = Type("Structure") Then
		
		FillPropertyValues(Object, FillingParameters);
		
		If Not Modified 
			AND FillingParameters.Modified Then
			
			Modified = True;
			
		EndIf;
		
	EndIf;

	
EndProcedure

#EndRegion

#Region ContactInformationSB

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationSB.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationSBClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationSBClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationSBClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationSBExecuteCommand(Command)
	
	ContactInformationSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisObject);
	
EndProcedure // Attachable_AllowObjectAttributesEditing()
// End

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion


