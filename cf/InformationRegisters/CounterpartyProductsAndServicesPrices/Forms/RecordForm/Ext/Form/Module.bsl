
&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(ProductsAndServices)
	
	Return ProductsAndServices.MeasurementUnit;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, StandardProcessing)
	If RecordWasRecorded Then
		Notify("CounterpartyPriceChanged", RecordWasRecorded);
	EndIf;
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		CurrentObject.Author = Users.CurrentUser();
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler AfterWrite form.
//
Procedure AfterWrite(WriteParameters)
	RecordWasRecorded = True;
EndProcedure

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If ValueIsFilled(Record.CounterpartyPriceKind) Then
		Counterparty = Record.CounterpartyPriceKind.Owner;	
	EndIf; 
	
	If Not ValueIsFilled(Record.SourceRecordKey.CounterpartyPriceKind) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.FillingValues.Property("Counterparty") AND ValueIsFilled(Parameters.FillingValues.Counterparty) Then
			Counterparty = Parameters.FillingValues.Counterparty;
		EndIf;
		
		If Parameters.Property("Counterparty") AND ValueIsFilled(Parameters.Counterparty) Then
			Counterparty = Parameters.Counterparty;	
		EndIf;
		
		If Parameters.FillingValues.Property("ProductsAndServices") AND ValueIsFilled(Parameters.FillingValues.ProductsAndServices) Then
			Record.MeasurementUnit = Parameters.FillingValues.ProductsAndServices.MeasurementUnit;	
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ProductsAndServicesOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsAndServicesOnChange(Record.ProductsAndServices);
	
EndProcedure

&AtClient
// Procedure - event handler StartChoice input field PriceKind.
//
Procedure PriceKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Counterparty) Then
		
		StandardProcessing = False;
		MessageText = NStr("en='Specify the counterparty to select the prices type.';ru='Укажите контрагента для выбора видов цен.'");
		CommonUseClientServer.MessageToUser(MessageText, , , "Counterparty");
		
	EndIf;
	
EndProcedure // PriceKindStartChoice()







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
