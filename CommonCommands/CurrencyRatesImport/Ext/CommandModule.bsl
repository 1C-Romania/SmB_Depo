#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotifyDescription = New NotifyDescription("ImportCurrencyClient", ThisObject);
	ShowQueryBox(NOTifyDescription, 
		NStr("en='The files will be imported from the service manager with full data on the exchange rates of all currencies for the whole period."
"The exchange rates marked in the data areas for import from the Internet will be replaced in the background job. Continue?';ru='Будет произведена загрузка файла с полной информацией по курсами всех валют за все время из менеджера сервиса."
"Курсы валют, помеченных в областях данных для загрузки из сети Интернет, будут заменены в фоновом задании. Продолжить?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ImportCurrencyClient(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ImportRates();
	
	ShowUserNotification(
		NStr("en='Importing is scheduled.';ru='Загрузка запланирована.'"), ,
		NStr("en='The exchange rates will be imported in the background mode within a short period of time.';ru='Курсы будут загружены в фоновом режиме через непродолжительное время.'"),
		PictureLib.Information32);
	
EndProcedure

&AtServer
Procedure ImportRates()
	
	CurrencyRatesServiceSaaS.ImportRates();
	
EndProcedure

#EndRegion
