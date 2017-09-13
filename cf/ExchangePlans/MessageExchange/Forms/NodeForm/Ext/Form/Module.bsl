
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	IsThisNode = (Object.Ref = MessageExchangeInternal.ThisNode());
	
	Items.InfoMessageGroup.Visible = Not IsThisNode;
	
	If Not IsThisNode Then
		
		If Object.Locked Then
			Items.InfoMessage.Title
				= NStr("en='This endpoint is locked.';ru='Эта конечная точка заблокирована.'");
		ElsIf Object.Leading Then
			Items.InfoMessage.Title
				= NStr("en='This endpoint is a leading one, that is, it initiates sending and receiving exchange messages for the current information system.';ru='Эта конечная точка является ведущей, т.е. инициирует отправку и получение сообщений обмена для текущей информационной системы.'");
		Else
			Items.InfoMessage.Title
				= NStr("en='This endpoint is a slave one, that is, it sends and receives exchange messages only by the current information system request.';ru='Эта конечная точка является ведомой, т.е. выполняет отправку и получение сообщений обмена только по требованию текущей информационной системы.'");
		EndIf;
		
		Items.MakeThisEndPointSubordinate.Visible = Object.Leading AND Not Object.Locked;
		
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
