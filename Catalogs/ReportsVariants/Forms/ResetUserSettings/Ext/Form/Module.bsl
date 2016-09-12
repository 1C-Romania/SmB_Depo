
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OptionsArray") Or TypeOf(Parameters.OptionsArray) <> Type("Array") Then
		ErrorText = NStr("en='Report variants are not specified.';ru='Не указаны варианты отчетов.'");
		Return;
	EndIf;
	
	If Not AreUserSettings(Parameters.OptionsArray) Then
		ErrorText = NStr("en='User settings of the selected reports variants (%1 unit) are either not specified or already reset.';ru='Пользовательские настройки выбранных вариантов отчетов (%1 шт) не заданы или уже сброшены.'");
		ErrorText = StrReplace(ErrorText, "%1", Format(Parameters.OptionsArray.Count(), "NZ=0; NG=0"));
		Return;
	EndIf;
	
	CustomizableOptions.LoadValues(Parameters.OptionsArray);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(ErrorText) Then
		Cancel = True;
		ShowMessageBox(, ErrorText);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ResetCommand(Command)
	VariantCount = CustomizableOptions.Count();
	If VariantCount = 0 Then
		ShowMessageBox(, NStr("en='Report variants are not specified.';ru='Не указаны варианты отчетов.'"));
		Return;
	EndIf;
	
	ResetUserSettingsServer(CustomizableOptions);
	If VariantCount = 1 Then
		OptionRef = CustomizableOptions[0].Value;
		NotificationTitle = NStr("en='User settings report variants are reset';ru='Сброшены пользовательские настройки варианта отчета'");
		NotificationRef    = GetURL(OptionRef);
		NotificationText     = String(OptionRef);
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("en='Custom settings"
"of report options are reset (%1 pcs.).';ru='Сброшены пользовательские настройки вариантов отчетов (%1 шт.).'");
		NotificationText = StrReplace(NotificationText, "%1", Format(VariantCount, "NZ=0; NG=0"));
		ShowUserNotification(, , NotificationText);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServerNoContext
Function ResetUserSettingsServer(Val CustomizableOptions)
	BeginTransaction();
	InformationRegisters.ReportsVariantsSettings.ResetSettings(CustomizableOptions.UnloadValues());
	CommitTransaction();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function AreUserSettings(OptionsArray)
	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsArray);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS Field1
	|FROM
	|	InformationRegister.ReportsVariantsSettings AS Settings
	|WHERE
	|	Settings.Variant IN(&OptionsArray)";
	
	AreUserSettings = Not Query.Execute().IsEmpty();
	Return AreUserSettings;
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
