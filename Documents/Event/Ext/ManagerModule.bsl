#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure PresentationFieldsReceiveDataProcessor(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Date");
	Fields.Add("EventType");
	
EndProcedure

Procedure PresentationReceiveDataProcessor(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	
	Presentation = "Event: " + Data.EventType + " from " + Format(Data.Date, "DF=dd.MM.yyyy");
	
EndProcedure

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind <> "DocumentForm"
		AND FormKind <> "ObjectForm" Then
		Return;
	EndIf;
	
	EventType = Undefined; 
	
	If Parameters.Property("Key") AND ValueIsFilled(Parameters.Key) Then
		EventType	= CommonUse.ObjectAttributeValue(Parameters.Key, "EventType");
	EndIf;
	
	// If the document is copied that we get event type from copied document.
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("CopyingValue")
			AND ValueIsFilled(Parameters.CopyingValue) Then
			EventType = CommonUse.ObjectAttributeValue(Parameters.CopyingValue, "EventType");
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure") Then
			If Parameters.FillingValues.Property("EventType") Then
				EventType	= Parameters.FillingValues.EventType;
			EndIf;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	EventForms = GetOperationKindMapToForms();
	SelectedForm = EventForms[EventType];
	If SelectedForm = Undefined Then
		SelectedForm = "DocumentForm";
	EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GetOperationKindMapToForms() Export

	EventForms = New Map;
	EventForms.Insert(Enums.EventTypes.Email, "EmailForm");
	EventForms.Insert(Enums.EventTypes.SMS,      "MessagesSMSForm");
	EventForms.Insert(Enums.EventTypes.PhoneCall,  "EventForm");
	EventForms.Insert(Enums.EventTypes.PrivateMeeting,     "EventForm");
	EventForms.Insert(Enums.EventTypes.Other,            "EventForm");
	
	Return EventForms;

EndFunction 

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf