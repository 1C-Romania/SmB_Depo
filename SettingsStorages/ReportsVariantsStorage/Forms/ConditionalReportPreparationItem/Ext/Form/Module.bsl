#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("SettingsComposer", SettingsComposer) Then
		Raise NStr("en = 'The SettingsLinker service parameter has not been passed.'");
	EndIf;
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("en = 'The ReportSettings service parameter has not been passed.'");
	EndIf;
	If Not Parameters.Property("CurrentCDHostIdentifier", CurrentCDHostIdentifier) Then
		Raise NStr("en = 'Service parameter ""CurrentKDNodeIdentifier"" is not sent.'");
	EndIf;
	If Not Parameters.Property("DCIdentifier", DCIdentifier) Then
		Raise NStr("en = 'Service parameter ""DCIdentifier"" is not sent.'");
	EndIf;
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	KDNode = KDNode(ThisObject);
	If KDNode = Undefined Then
		Raise NStr("en = 'Report node is not found.'");
	EndIf;
	KDItem = KDNode.GetObjectByID(DCIdentifier);
	If KDItem = Undefined Then
		Raise NStr("en = 'Item of conditional appearance is not found.'");
	EndIf;
	
	SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	EditableKDItem = SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	FillPropertyValues(EditableKDItem, KDItem);
	
	CloseOnChoice = False;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure Select(Command)
	ChooseAndClose();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ChooseAndClose()
	KDItem = SettingsComposer.Settings.ConditionalAppearance.Items[0];
	NotifyChoice(KDItem);
	Close(KDItem);
EndProcedure

&AtClientAtServerNoContext
Function KDNode(ThisObject)
	If ThisObject.CurrentCDHostIdentifier = Undefined Then
		Return ThisObject.SettingsComposer.UserSettings;
	Else
		CurrentKDNode = ThisObject.SettingsComposer.Settings.GetObjectByID(ThisObject.CurrentCDHostIdentifier);
		Return CurrentKDNode.ConditionalAppearance;
	EndIf;
EndFunction

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
