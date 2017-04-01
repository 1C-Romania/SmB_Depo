
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Record.SourceRecordKey) Then
		Record.Period = CurrentSessionDate();
	EndIf;
	
	FillCurrency();

	CurrencySelectionAvailable = Not Parameters.FillingValues.Property("Currency") AND Not ValueIsFilled(Parameters.Key);
	Items.CurrencyLabel.Visible = Not CurrencySelectionAvailable;
	Items.CurrencyList.Visible = CurrencySelectionAvailable;
	
	WindowOptionsKey = ?(CurrencySelectionAvailable, "WithChoiceOfCurrency", "WithoutSelectCurrencies");
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Record_CurrencyRates", WriteParameters, Record);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not CurrencySelectionAvailable Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("CurrencyList");
		CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CurrencyOnChange(Item)
	Record.Currency = CurrencyList;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillCurrency()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS SymbolicCode,
	|	Currencies.DescriptionFull AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description";
	
	SelectionOfCurrency = Query.Execute().Select();
	
	While SelectionOfCurrency.Next() Do
		PresentationOfCurrency = StringFunctionsClientServer.SubstituteParametersInString("%1 (%2)", SelectionOfCurrency.Description, SelectionOfCurrency.SymbolicCode);
		Items.CurrencyList.ChoiceList.Add(SelectionOfCurrency.Ref, PresentationOfCurrency);
		If SelectionOfCurrency.Ref = Record.Currency Then
			CurrencyLabel = PresentationOfCurrency;
			CurrencyList = Record.Currency;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
