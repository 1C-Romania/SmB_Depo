
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Filling currency list from IUC.
	CloseOnChoice = False;
	FillCurrenciesTable();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCurrencyList

&AtClient
Procedure CurrencyListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessChoiceInCurrencyList(StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseRun()
	
	ProcessChoiceInCurrencyList();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillCurrenciesTable()
	
	// Fills currency list from IUC layout.
	
	XMLClassifier = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(XMLClassifier).Data;
	
	For Each WriteOKV IN ClassifierTable Do
		NewRow = Currencies.Add();
		NewRow.DigitalCurrencyCode         = WriteOKV.Code;
		NewRow.AlphabeticCurrencyCode      = WriteOKV.CodeSymbol;
		NewRow.Description                 = WriteOKV.Name;
		NewRow.CountriesAndTerritories     = WriteOKV.Description;
		NewRow.Importing                   = WriteOKV.RBCLoading;
		NewRow.InWordParametersInHomeLanguage  = WriteOKV.NumerationItemOptions;
	EndDo;
	
EndProcedure

&AtServer
Function SaveSelectedRows(Val SelectedRows, IsRates)
	
	IsRates = False;
	CurrentRef = Undefined;
	
	For Each LineNumber IN SelectedRows Do
		CurrentData = Currencies[LineNumber];
		
		RowInBase = Catalogs.Currencies.FindByCode(CurrentData.DigitalCurrencyCode);
		If ValueIsFilled(RowInBase) Then
			If LineNumber = Items.CurrenciesList.CurrentRow Or CurrentRef = Undefined Then
				CurrentRef = RowInBase;
			EndIf;
			Continue;
		EndIf;
		
		NewRow = Catalogs.Currencies.CreateItem();
		NewRow.Code                       = CurrentData.DigitalCurrencyCode;
		NewRow.Description              = CurrentData.AlphabeticCurrencyCode;
		NewRow.DescriptionFull        = CurrentData.Description;
		If CurrentData.Importing Then
			NewRow.SetRateMethod = Enums.CurrencyRateSetMethods.ExportFromInternet;
		Else
			NewRow.SetRateMethod = Enums.CurrencyRateSetMethods.ManualInput;
		EndIf;
		NewRow.InWordParametersInHomeLanguage = CurrentData.InWordParametersInHomeLanguage;
		NewRow.Write();
		
		If LineNumber = Items.CurrenciesList.CurrentRow Or CurrentRef = Undefined Then
			CurrentRef = NewRow.Ref;
		EndIf;
		
		If CurrentData.Importing Then 
			IsRates = True;
		EndIf;
		
	EndDo;
	
	Return CurrentRef;

EndFunction

&AtClient
Procedure ProcessChoiceInCurrencyList(StandardProcessing = Undefined)
	Var IsRates;
	
	// Add catalog item and display result to user.
	StandardProcessing = False;
	
	CurrentRef = SaveSelectedRows(Items.CurrenciesList.SelectedRows, IsRates);
	
	NotifyChoice(CurrentRef);
	
	ShowUserNotification(
		NStr("en='Currencies are added.';ru='Валюты добавлены.'"), ,
		?(StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled AND IsRates, 
			NStr("en='Exchange rates will be imported automatically after a short time.';ru='Курсы будут загружены автоматически через непродолжительное время.'"), ""),
		PictureLib.Information32);
	Close();
	
EndProcedure

#EndRegion
