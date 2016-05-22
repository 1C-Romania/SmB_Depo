
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	IsThisNode = (Object.Ref = MessageExchangeInternal.ThisNode());
	
	Items.InfoMessageGroup.Visible = Not IsThisNode;
	
	If Not IsThisNode Then
		
		If Object.Blocked Then
			Items.InfoMessage.Title
				= NStr("en = 'This end point is locked.'");
		ElsIf Object.Leading Then
			Items.InfoMessage.Title
				= NStr("en = 'This end point is leading that is it initiates sending and getting exchange messages for the current information system.'");
		Else
			Items.InfoMessage.Title
				= NStr("en = 'This end point is slave which means that it sends and receives exchange messages only upon the request of the current information system.'");
		EndIf;
		
		Items.MakeThisEndPointSubordinate.Visible = Object.Leading AND Not Object.Blocked;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify(MessageExchangeClient.EndPointFormClosedEventName());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = MessageExchangeClient.EventNameLeadingEndPointSet() Then
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MakeThisEndPointSubordinate(Command)
	
	FormParameters = New Structure("EndPoint", Object.Ref);
	
	OpenForm("CommonForm.LeadingEndPointSetting", FormParameters, ThisObject, Object.Ref);
	
EndProcedure

#EndRegion
