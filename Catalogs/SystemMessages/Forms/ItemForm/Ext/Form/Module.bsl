
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MessageBody = CommonUse.ObjectAttributeValue(Object.Ref, "MessageBody").Get();
	
	If TypeOf(MessageBody) = Type("String") Then
		
		MessageBodyPresentation = MessageBody;
		
	Else
		
		Try
			MessageBodyPresentation = CommonUse.ValueToXMLString(MessageBody);
		Except
			MessageBodyPresentation = NStr("en = 'Message body can not be presented by the row.'");
		EndTry;
		
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
