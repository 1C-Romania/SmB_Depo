#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS TO INITIALIZE AND FILL THE DOCUMENT

// Initializes the settlement reconciliation act
//
Procedure InitializeDocument() Export
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = Users.CurrentUser();
	EndIf;
	
	If Not ValueIsFilled(Status) Then
		Status = Enums.SettlementsReconciliationStatuses.Created;
	EndIf;
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod = CurrentDate();
	EndIf;

EndProcedure // InitializeDocument()

// Fills a document header according to the structure passed from the assistant
//
// Parameters:
// FillingData - Structure
//
Procedure FillDocumentByAssistantData(FillingData)
	
	FillPropertyValues(ThisObject, FillingData);
	
	FillingData.Insert("Date", Date);
	
EndProcedure // FillDocumentByAssistantData()

///////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS.

// Procedure - event handler "OnCopy".
//
Procedure OnCopy(CopiedObject)
	
	// Clear the document tabular section.
	If CounterpartyData.Count() > 0 Then
		CounterpartyData.Clear();
	EndIf;
	
EndProcedure // OnCopy()

// Procedure - event handler "FillingProcessor".
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillDocumentByAssistantData(FillingData);
	EndIf;
	
	InitializeDocument();
	
EndProcedure // FillingProcessor()

#EndIf