﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en='Data processor is not aimed for being used directly';ru='Обработка не предназначена для непосредственного использования.'");
	EndIf;
	
	SkipExit = Parameters.SkipExit;
	
	Items.MessageText.Title = Parameters.MessageText;
	Items.RecommendedPlatformVersion.Title = Parameters.RecommendedPlatformVersion;
	SystemInfo = New SystemInfo;
	
	TextCondition = ?(Parameters.Done, NStr("en='Required';ru='Required'"), NStr("en='recommended';ru='рекомендуемые'"));
	Items.Version.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		Items.Version.Title, TextCondition, SystemInfo.AppVersion);
	
	If Parameters.Done Then
		Items.QuestionText.Visible = False;
		Items.FormNo.Visible     = False;
		Title = NStr("en='It is required to update platform version';ru='Необходимо обновить версию платформы'");
	EndIf;
	
	If (ClientApplicationInterfaceCurrentVariant() <> ClientApplicationInterfaceVariant.Taxi) Then
		Items.RecommendedPlatformVersion.Font = New Font(,, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not ActionDetermined Then
		ActionDetermined = True;
		
		If Not SkipExit Then
			Terminate();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure HyperlinkTextClick(Item)
	
	OpenForm("DataProcessor.NotRecommendedPlatformVersion.Form.PlatformUpdateOrder",,ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ContinueWork(Command)
	
	ActionDetermined = True;
	Close("Continue");
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	ActionDetermined = True;
	If Not SkipExit Then
		Terminate();
	EndIf;
	Close();
	
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
