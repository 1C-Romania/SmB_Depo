﻿
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// OnCreateAtServer event handler of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// On call from the classifier.
	If Parameters.Property("Code") Then
		Object.Code = Parameters.Code;
	EndIf;	
	
	If Parameters.Property("Description") Then
		Object.Description = Parameters.Description;
	EndIf;
	
	If Parameters.Property("InternationalAbbreviation") Then
		Object.InternationalAbbreviation = Parameters.InternationalAbbreviation;
	EndIf;
	
	If Parameters.Property("DescriptionFull") Then
		Object.DescriptionFull = Parameters.DescriptionFull;
	EndIf;	
	
EndProcedure // OnCreateAtServer()



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


// Rise { Sargsyan N 2016-08-17
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PresentationsChanged" Then
		RiseFillPresentations(Parameter);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure  RiseFillPresentations(Table)
	Object.MultilingualPresentations.Clear();
	Object.MultilingualPresentations.Load(Table.Unload());
EndProcedure
// Rise } Sargsyan N 2016-08-17
