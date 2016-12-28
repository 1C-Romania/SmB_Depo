#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
	// If the parameters of selection by products and services are linked, then we will get the selection data from the "UOM" catalog.
		StandardProcessing = False;
		ChoiceData = Catalogs.UOM.GetChoiceData(Parameters);
	EndIf;
	
EndProcedure

// Rise { Sargsyan N 2016-08-17 
Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	StandardProcessing = False;
	
	Fields.Add("Description");
	Fields.Add("Ref");

EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	StandardProcessing  = False;
	CurrentPresentation = PresentationsReUse.GetObjectPresentation(Data.Ref, PresentationsReUse.GetCurrentUserLanguageCode(),"UOMClassifier"); 
	
	Если CurrentPresentation <> Undefined Тогда
		Presentation = CurrentPresentation;
	Иначе
		Presentation = Data.Description;
	КонецЕсли;

EndProcedure
// Rise } Sargsyan N 2016-08-17


#EndRegion
