
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseServerCall.ThisIsFirstLaunch() Then
		Constants.FirstLaunchPassed.Set(False);
	EndIf;
	
	FillCountries();
	FillChoiceList();
	
EndProcedure

&AtServer
Procedure FillCountries()
	
	// Fill countries from template
	Obj = FormAttributeToValue("Object");
	Template = Obj.GetTemplate("Countries");
	AreaCountries = Template.GetArea("Countries");
	Top = AreaCountries.Area().Top;
	Bottom = AreaCountries.Area().Bottom;
	
	For RowNumber = Top To Bottom Do
		
		StructureCountry = New Structure("Country, Description, Postfix");
		StructureCountry.Country = AreaCountries.Area(RowNumber, 1, RowNumber,1).Text;
		StructureCountry.Description = AreaCountries.Area(RowNumber, 2, RowNumber, 2).Text;
		StructureCountry.Postfix = AreaCountries.Area(RowNumber, 3, RowNumber, 3).Text;
		
		If ValueIsFilled(StructureCountry.Country) Then
			NewRow = Countries.Add();
			FillPropertyValues(NewRow, StructureCountry);
		EndIf
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillChoiceList()
	
	ArrayOfCountries = Countries.Unload().UnloadColumn("Country");
	Items.Country.ChoiceList.LoadValues(ArrayOfCountries);
	If Countries.Count() > 0 Then
		Object.Country = Countries[0].Country;
		Object.Descriprion = Countries[0].Description;
		Postfix = Countries[0].Postfix;
	EndIf;
	
EndProcedure

&AtClient
Procedure CountryOnChange(Item)
	
	Rows = Countries.FindRows(New Structure("Country", Object.Country));
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	Object.Descriprion = Rows[0].Description;
	Postfix = Rows[0].Postfix;
	
EndProcedure

&AtClient
Procedure TipOfChoiceCountryURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	ShowMessageBox(, NStr("ru='Здесь будет подсказка.'; 
						  |en='This is tip'"));
	
EndProcedure

&AtClient
Procedure Go(Command)
	
	Dialog = New FileDialog(FileDialogMode.Open);
	FileFilter = NStr("ru = 'Файл локализации'; en = 'Localization file'") + "(*.xml)|*.xml";
	Dialog.Filter = FileFilter;
	Dialog.Multiselect = False;
	Dialog.Title = NStr("ru = 'Выберите файл'; en = 'Choose file'");
	
	If Dialog.Choose() Then
	
		// Find the file
		FileName = Dialog.FullFileName;
		File = New File(FileName);
		If File.Exist() Then
			// If file exist then fill data from file at server.
			Result = FillPredefinedDataAtServer(FileName);
			//Close(True);
			
			If Result Then
				Notification = New NotifyDescription("NotificationOfCompletionDescriptionSuccess", ThisObject);	
				
				ShowMessageBox(Notification, NStr("ru='Первоначальное заполнение данных прошло успешно!';en='Preloading data finished successfully!'"), 0, NStr("ru='Информация.';en='Information.'"));
			Else
				Notification = New NotifyDescription("NotificationOfCompletionDescriptionNotSuccess", ThisObject);	
				
				ShowMessageBox(Notification, NStr("ru='Первоначальное заполнение данных завершено с ошибками!';en='Preloading data finished with errors!'"), 0, NStr("ru='Информация.';en='Information.'"));
			EndIf;
		Else
			CommonUseClientServer.MessageToUser(
				StrTemplate(NStr("ru='Файл %1 не найден.';en='File %1 was not found.'"), FileName));
		EndIf;
		
	EndIf;
EndProcedure

&AtClient
Procedure NotificationOfCompletionDescriptionSuccess(Parametrs) Export 
	Close(True);
EndProcedure

&AtClient
Procedure NotificationOfCompletionDescriptionNotSuccess(Parametrs) Export 

EndProcedure

&AtServer
Function FillPredefinedDataAtServer(FileName)
	
	Obj = FormAttributeToValue("Object");
	Result = Obj.PredefinedDataAtServer(FileName);
	
	If Result Then 
		Constants.FirstLaunchPassed.Set(True);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function PathToFile()

	Return "C:\";

EndFunction

&AtClient
Function NameOfFile(Postfix)

	Return StrTemplate("FirstData_%1.xml", PostFix);

EndFunction

&AtServer
Procedure OnOpenAtServer()
	If  Constants.FirstLaunchPassed.Get() Then
		Close(True);
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	OnOpenAtServer();
EndProcedure
