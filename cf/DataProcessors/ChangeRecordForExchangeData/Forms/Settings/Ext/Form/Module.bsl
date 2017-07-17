
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	IDQueryConsole = "QueryConsole";
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	
	String = TrimAll(CurrentObject.SettingAddressExternalDataQueryProcessors);
	If Lower(Right(String, 4)) = ".epf" Then
		UseQueryConsoleVariant = 2;
	ElsIf Metadata.DataProcessors.Find(String) <> Undefined Then
		UseQueryConsoleVariant = 1;
		String = "";	
	Else 
		UseQueryConsoleVariant = 0;
		String = "";
	EndIf;
	CurrentObject.SettingAddressExternalDataQueryProcessors = String;
	
	ThisObject(CurrentObject);
	
	ChoiceList = Items.OutsideDataProcessorQuery.ChoiceList;
	
	// Allow in the content of metadata, only if there is predefined.
	If Metadata.DataProcessors.Find(IDQueryConsole) = Undefined Then
		CurItem = ChoiceList.FindByValue(1);
		If CurItem <> Undefined Then
			ChoiceList.Delete(CurItem);
		EndIf;
	EndIf;
	
	// Option string from the file
	If CurrentObject.ThisIsFileBase() Then
		CurItem = ChoiceList.FindByValue(2);
		If CurItem <> Undefined Then
			CurItem.Presentation = NStr("en='In the directory:';ru='В каталоге:'");
		EndIf;
	EndIf;

	// Allow SSL, only if it exists and it is of the required version.
	Items.GroupSL.Visible = CurrentObject.ConfigurationIsSupportingSLE
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers
//

&AtClient
Procedure DataProcessorQueryPathOnChange(Item)
	UseQueryConsoleVariant = 2;
EndProcedure

&AtClient
Procedure QueryDataProcessorPathStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	AdditionalParameters = New Structure();
	
	SuggestionText = NStr("en='To open the directory, install the file operation extension.';ru='Для открытия каталога необходимо необходимо установить расширение работы с файлами.'");
	OnCloseNotifyDescription = New NotifyDescription("AfterWorksWithFilesExpansionCheck", ThisForm, AdditionalParameters);
	
	AlertDescriptionEnd = New NotifyDescription("ShowQuestionOnFileOperationsExtensionSettingEnd",
		ThisObject, OnCloseNotifyDescription);
	
#If Not WebClient Then
	// The extension is always enabled in thin and thick client.
	ExecuteNotifyProcessing(AlertDescriptionEnd, "ConnectionNotRequired");
	Return;
#EndIf
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AlertDescriptionEnd", AlertDescriptionEnd);
	AdditionalParameters.Insert("SuggestionText", SuggestionText);
	AdditionalParameters.Insert("PossibleToContinueWithoutInstallation", True);
	
	Notification = New NotifyDescription("ShowQuestionOnFileOperationsExtensionSettingOnExtensionSetting",
		ThisObject, AdditionalParameters);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterWorksWithFilesExpansionCheck(Result, AdditionalParameters) Export
	
	If Result Then
		
		Dialog = New FileDialog(FileDialogMode.Open);
		
		Dialog.CheckFileExist = True;
		Dialog.Filter = NStr("en='External data processors (*.epf) | *.epf';ru='Внешние обработки (*.epf)|*.epf'");
		
		Notification = New NotifyDescription("AfterFileSelection", ThisForm, AdditionalParameters);
		Dialog.Show(Notification);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterFileSelection(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles.Count() = 1 Then
		UseQueryConsoleVariant = 2;
		SetSettingAddressOfExternalQueryProcessors(SelectedFiles[0]);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure ConfirmSelection(Command)
	
	Checking = CheckSettings();
	If Checking.HasErrors Then
		// Reports about errors
		If Checking.SettingAddressExternalDataQueryProcessors <> Undefined Then
			ShowMessageAboutError(Checking.SettingAddressExternalDataQueryProcessors, "Object.SettingAddressExternalDataQueryProcessors");
			Return;
		EndIf;
	EndIf;
	
	// Everything is successful
	SaveSettings();
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

&AtClient
Procedure ShowMessageAboutError(Text, AttributeName = Undefined)
	
	If AttributeName = Undefined Then
		ErrorTitle = NStr("en='Error';ru='Ошибка'");
		ShowMessageBox(, Text, , ErrorTitle);
		Return;
	EndIf;
	
	Message = New UserMessage();
	Message.Text = Text;
	Message.Field  = AttributeName;
	Message.SetData(ThisObject);
	Message.Message();
EndProcedure	

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CheckSettings()
	CurrentObject = ThisObject();
	
	If UseQueryConsoleVariant = 2 Then
		
		CurrentObject.SettingAddressExternalDataQueryProcessors = TrimAll(CurrentObject.SettingAddressExternalDataQueryProcessors);
		If Left(CurrentObject.SettingAddressExternalDataQueryProcessors, 1) = """" 
			AND Right(CurrentObject.SettingAddressExternalDataQueryProcessors, 1) = """"
		Then
			CurrentObject.SettingAddressExternalDataQueryProcessors = Mid(CurrentObject.SettingAddressExternalDataQueryProcessors, 
				2, StrLen(CurrentObject.SettingAddressExternalDataQueryProcessors) - 2);
		EndIf;
		
		If Lower(Right(TrimAll(CurrentObject.SettingAddressExternalDataQueryProcessors), 4)) <> ".epf" Then
			CurrentObject.SettingAddressExternalDataQueryProcessors = TrimAll(CurrentObject.SettingAddressExternalDataQueryProcessors) + ".epf";
		EndIf;
		
	ElsIf UseQueryConsoleVariant = 0 Then
		CurrentObject.SettingAddressExternalDataQueryProcessors = "";
		
	EndIf;
	
	Result = CurrentObject.CheckSettingsCorrectness();
	ThisObject(CurrentObject);
	
	Return Result;
EndFunction

&AtServer
Procedure SaveSettings()
	CurrentObject = ThisObject();
	If UseQueryConsoleVariant = 0 Then
		CurrentObject.SettingAddressExternalDataQueryProcessors = "";
	ElsIf UseQueryConsoleVariant = 1 Then
		CurrentObject.SettingAddressExternalDataQueryProcessors = IDQueryConsole		;
	EndIf;
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure SetSettingAddressOfExternalQueryProcessors(PathToFile)
	CurrentObject = ThisObject();
	CurrentObject.SettingAddressExternalDataQueryProcessors = PathToFile;
	ThisObject(CurrentObject);
EndProcedure

#EndRegion
