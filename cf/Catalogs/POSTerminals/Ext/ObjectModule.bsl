#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckPettyCash(Cancel);
	
	If UseWithoutEquipmentConnection Then
		
		AttributeToBeDeleted = CheckedAttributes.Find("Peripherals");
		If AttributeToBeDeleted <> Undefined Then
			CheckedAttributes.Delete(CheckedAttributes.Find("Peripherals"));
		EndIf;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UseWithoutEquipmentConnection Then
		Peripherals = Undefined;
	EndIf;
	
EndProcedure // BeforeWrite()

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure checks the petty cash specified in POS terminal.
//
Procedure CheckPettyCash(Cancel)
	
	If TypeOf(PettyCash) = Type("CatalogRef.CashRegisters") Then
		Attributes = Catalogs.CashRegisters.GetCashRegisterAttributes(PettyCash);
		
		If ValueIsFilled(Company)
		   AND ValueIsFilled(Attributes.Company)
		   AND Company <> Attributes.Company Then
		
			Text = NStr("en='The company of the cash funds does not correspond to the company of the acquiring contract.';ru='Организация кассы не соответствует организации договора эквайринга'");
			CommonUseClientServer.MessageToUser(
				Text,
				ThisObject,
				"PettyCash",
				,
				Cancel
			);
		EndIf;
		
	EndIf;
	
EndProcedure // CheckPettyCash()

#EndRegion

#EndIf