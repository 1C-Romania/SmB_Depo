#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	Result.Add("SetRateMethod");
	Result.Add("Markup");
	Result.Add("MainCurrency");
	Result.Add("RateCalculationFormula");
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data import from the file

// Prohibits to import data to this catalog
// from subsystem "DataLoadFromFile" because the catalog uses its data update method.
//
Function UseDataLoadFromFile() Export
	Return False;
EndFunction

// Rise { Sargsyan N 2016-08-17 
Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Description");
	Fields.Add("Ref");

EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)  	

	StandardProcessing  = False;
	CurrentPresentation = PresentationsReUse.GetObjectPresentation(Data.Ref, PresentationsReUse.GetCurrentUserLanguageCode(),"Currencies");

	Если CurrentPresentation <> Undefined Тогда
		Presentation = CurrentPresentation;
	Иначе
		Presentation = Data.Description;
	КонецЕсли;
	
EndProcedure
// Rise } Sargsyan N 2016-08-17


#EndRegion

#EndIf