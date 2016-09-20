
///////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Pass initialization to guarantee getting form by transfer the parameter "AutoTest"
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	If Record.Workplace = Catalogs.Workplaces.EmptyRef() Then
		Record.Workplace = SessionParameters.ClientWorkplace;
	EndIf;

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure DeviceChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If DeviceWorkplace(ValueSelected) = Record.Workplace Then
		StandardProcessing = False;
		MessageText = NStr("en='Selected device is already linked to this workplace!
		|Specify the remote device to use by network';ru='Выбранное устройство уже привязано к данному рабочему месту!
		|Укажите удаленное устройство для использования по сети'");
		CommonUseClientServer.MessageToUser(MessageText, , );
	EndIf;

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Function DeviceWorkplace(Device)

	Return Device.Workplace;

EndFunction



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
