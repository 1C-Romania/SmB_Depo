&AtClient
Var AttributesInitialValues;

#Region ServiceProceduresAndFunctions

&AtClient
Procedure WereMadeChanges(ParametersStructure)
	
	HasChanges = False;
	
	For Each AttributeValues IN AttributesInitialValues Do
		
		//If the value in the background is changed, then it needs to be added to the structure that will be passed to the document
		FormAttributeValue = ThisForm[AttributeValues.Key];
		If AttributeValues.Value <> FormAttributeValue Then
			
			ParametersStructure.Insert(AttributeValues.Key, FormAttributeValue);
			HasChanges = True;
			
		EndIf;
		
	EndDo;
	
	ParametersStructure.Insert("HasChanges", HasChanges);
	
EndProcedure

&AtServer
Procedure FillShippingAddressChoiceList(ItemOfAddress, Owner, CIKind, ClearList = True)
	
	ArrayOfOwners = New Array;
	ArrayOfOwners.Add(Owner);
	
	Addresses = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , CIKind);
	
	For Each Address IN Addresses Do
		
		ItemOfAddress.ChoiceList.Add(Address.Presentation);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillShippingAddress(ClearField = False)
	
	If ClearField Then
		
		ShippingAddress = "";
		
	EndIf;
	
	Items.ShippingAddress.ChoiceList.Clear();
	
	ShippingAddressesSource = ?(ValueIsFilled(Consignee), Consignee, Counterparty);
	FillShippingAddressChoiceList(Items.ShippingAddress, ShippingAddressesSource, PredefinedValue("Catalog.ContactInformationTypes.CounterpartyShippingAddress"));
	
EndProcedure

&AtServer
Procedure FillPrintingReasons(OrdersArray)
	
	If ValueIsFilled(CounterpartyContract) Then
		
		Items.StampBase.ChoiceList.Add(NStr("en = 'Contract: '") + String(CounterpartyContract.Description));
		
	EndIf;
	
	If ValueIsFilled(BasisDocument)
		AND TypeOf(BasisDocument) = Type("DocumentRef.InvoiceForPayment") Then
		
		Items.StampBase.ChoiceList.Add(String(BasisDocument));
		
	EndIf;
	
	If OrdersArray.Count() > 0 Then
		
		For Each ArrayRow IN OrdersArray Do
			
			Items.StampBase.ChoiceList.Add(ArrayRow);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisForm, Parameters, , "CloseOnChoice, CloseOnOwnerClose, PurposeUseKey, ReadOnly");
	
	If Source = "CustomerInvoice" 
		OR Source = "ProcessingReport" Then
		
		FillPrintingReasons(Parameters.OrdersArray);
		FillShippingAddress();
		
	ElsIf Source = "InventoryTransfer" Then
		
		FillShippingAddressChoiceList(Items.ShippingAddress, Parameters.StructuralUnitPayee, Catalogs.ContactInformationTypes.StructuralUnitsActualAddress);
		CommonUseClientServer.SetFormItemProperty(Items, "GroupBasis", "Visible", False);
		CommonUseClientServer.SetFormItemProperty(Items, "GroupPrintAttributes", "Visible", False);
		CommonUseClientServer.SetFormItemProperty(Items, "Consignor", "Visible", False);
		CommonUseClientServer.SetFormItemProperty(Items, "Consignee", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttributesInitialValues = New Structure;
	
	// Information about the current document
	AttributesInitialValues.Insert("CounterpartyContract",			CounterpartyContract);
	AttributesInitialValues.Insert("StampBase",				StampBase);
	
	// Bank accounts
	AttributesInitialValues.Insert("BankAccountOfTheCompany",	BankAccountOfTheCompany);
	AttributesInitialValues.Insert("CounterpartyBankAcc",	CounterpartyBankAcc);
	
	// Logistics
	AttributesInitialValues.Insert("Consignor",			Consignor);
	AttributesInitialValues.Insert("Consignee",				Consignee);
	AttributesInitialValues.Insert("ShippingAddress",				ShippingAddress);
	
	// Carrier
	AttributesInitialValues.Insert("Carrier",					Carrier);
	AttributesInitialValues.Insert("CarrierBankAccount",	CarrierBankAccount);
	AttributesInitialValues.Insert("DeliveryTerm",				DeliveryTerm);
	AttributesInitialValues.Insert("Driver",					Driver);
	AttributesInitialValues.Insert("Vehicle",					Vehicle);
	AttributesInitialValues.Insert("trailer",						trailer);
	
	// Responsible individuals
	AttributesInitialValues.Insert("Head",				Head);
	AttributesInitialValues.Insert("HeadPosition",		HeadPosition);
	AttributesInitialValues.Insert("ChiefAccountant",			ChiefAccountant);
	AttributesInitialValues.Insert("Released",					Released);
	AttributesInitialValues.Insert("ReleasedPosition",			ReleasedPosition);
	
	// PowerOfAttorney
	AttributesInitialValues.Insert("PowerOfAttorneyNumber",			PowerOfAttorneyNumber);
	AttributesInitialValues.Insert("PowerOfAttorneyDate",			PowerOfAttorneyDate);
	AttributesInitialValues.Insert("PowerOfAttorneyIssued",			PowerOfAttorneyIssued);
	AttributesInitialValues.Insert("PowerAttorneyPerson",			PowerAttorneyPerson);
	
EndProcedure

&AtClient
Procedure SaveFormChanges()
	
	ParametersStructure = New Structure;
	WereMadeChanges(ParametersStructure);
	
	If ParametersStructure.HasChanges Then
		
		ParametersStructure.Delete("HasChanges");
		NotifyChoice(ParametersStructure);
		
	Else
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	SaveFormChanges();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure ConsigneeOnChange(Item)
	
	If Consignee <> Counterparty Then
		
		FillShippingAddress(True);
		
	EndIf;
	
EndProcedure

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
