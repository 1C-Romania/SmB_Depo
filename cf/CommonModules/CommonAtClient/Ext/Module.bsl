Function GetUserSettingsValue(Val Setting) Export
	
	If TypeOf(Setting) = Type("String") Then
		UserSetting = PredefinedValue("ChartOfCharacteristicTypes.UserSettings." + Setting);
	ElsIf TypeOf(Setting) = Type("ChartOfCharacteristicTypesRef.UserSettings") Then
		UserSetting = Setting;
	EndIf;
	
	For Each UserSettingsInfo In ApplicationParameters.UserSettingsValue Do
		If UserSettingsInfo.Setting = UserSetting Then
			Return UserSettingsInfo.Value;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction
// Jack 27.06.2017

//Procedure AfterMessageBoxPerformInfoBaseUpdate(Parameters) Export 
//	Exit();
//EndProcedure

//Procedure AfterQueryBoxPerformInfoBaseUpdate(Answer, ApplicationParameters) Export 
//	If Answer = DialogReturnCode.Yes Then
//		If Not ApplicationParameters = Undefined And ApplicationParameters.Property("RequestForInfobaseClosingLocal") Then
//			ApplicationParameters.RequestForInfobaseClosingLocal = False;
//		EndIf;
//		Exit();
//	EndIf;	
//EndProcedure

//Procedure NotificationProcessingPerformInfoBaseUpdate(Answer, Parameters) Export 
//	If ApplicationParameters.NeedUpdateInfoBase Then
//		QueryText	= Nstr("en = 'Infobase update was not performed! Do you want to shutdown system?';
//							|pl = 'Aktualizacja bazy informacyjnej nie została wykonana! Czy chcesz zamknąć system?'");
//		QueryMode	= QuestionDialogMode.YesNo;
//		Notify		= New NotifyDescription("AfterQueryBoxPerformInfoBaseUpdate", CommonAtClient, ApplicationParameters);
//		
//		ShowQueryBox(Notify, QueryText, QueryMode);

//		Return;
//	EndIf;
//EndProcedure

//Procedure PerformInfoBaseUpdate() Export
//	
//	If Not ApplicationParameters = Undefined Then
//		If Not ApplicationParameters.NeedUpdateInfoBase Then
//			Return;
//		EndIf;
//		
//		AccessRightExclusiveMode = ApplicationParameters.AccessRightExclusiveMode;
//		AccessRightUpdateInfoBase = ApplicationParameters.AccessRightUpdateInfoBase;
//		If Not ApplicationParameters.IsExclusiveMode Then
//			Notify	= New NotifyDescription("AfterMessageBoxPerformInfoBaseUpdate", CommonAtClient);
//			
//			ShowMessageBox(Notify, Nstr("en = 'Could not set exclusive mode to perform infobase update. System will be shutdowned!';
//										|pl = 'Nie udało się przełączyć się do trybu monopolowego dla wykonania aktualizacji bazy informacyjnej. System zostanie zamknięty!'"));

//			Return;
//		EndIf;
//		
//	Else
//		If Not CommonAtServer.NeedUpdateInfoBase() Then
//			Return;
//		EndIf;
//		AccessRightExclusiveMode = CommonAtServer.IsAccessRight("ExclusiveMode", "Metadata");
//		AccessRightUpdateInfoBase = CommonAtServer.IsAccessRight("Use", "Metadata.DataProcessors.UpdateInfoBase") And CommonAtServer.IsAccessRight("View", "Metadata.DataProcessors.UpdateInfoBase");
//	EndIf;

//	If Not AccessRightExclusiveMode Or Not AccessRightUpdateInfoBase Then
//		Notify	= New NotifyDescription("AfterMessageBoxPerformInfoBaseUpdate", CommonAtClient);
//		
//		ShowMessageBox(Notify, Nstr("en = 'Insufficient rights to perform infobase update. System will be shutdowned!';
//									|pl = 'Brak uprawnień dla wykonania aktualizacji bazy informacyjnej. System zostanie zamknięty!'"));
//		
//		Return;
//	EndIf;
//	
//	Notify		= New NotifyDescription("NotificationProcessingPerformInfoBaseUpdate", CommonAtClient);
//	OpenForm("DataProcessor.UpdateInfoBase.Form.UpdateProgress", New Structure(CommonAtServer.GetInfoBaseUpdateProcessors()));
//EndProcedure

//Procedure BeforeStart() Export
//	ApplicationParameters = CommonAtClientCached.StartupClientParameters();
//	ReportTempSettingStructure = New Structure();
//EndProcedure

//Procedure OnStart(Settings) Export
//	
//	PerformInfoBaseUpdate();
//	If NOT IsBlankString(ApplicationParameters.CustomCaption) Then
//		SetClientApplicationCaption(TrimAll(ApplicationParameters.CustomCaption) + " " + GetClientApplicationCaption());
//	EndIf;	
//	
//	If Not Settings.DontShowUserSettingsWizardOnStart Then
//		If Settings.Right_Administration_ConfigurationAdministration Then
//			OpenForm("DataProcessor.InfobaseUsers.Form.UserFormForAdministrationManaged");
//		Else	
//			OpenForm("DataProcessor.InfobaseUsers.Form.UserFormManaged");
//		EndIf;	
//	EndIf;
//	
//	SetInterfaceFunctionalOptionParameters(New Structure("IdentifierFiscalPrinter", ApplicationParameters.IdentifierFiscalPrinter), "Identifier");
//EndProcedure

//Procedure UpdateDocumentPriceAndDiscount(Form) Export
//	
//EndProcedure

//Function CreateValueStructureToPut(Val Source, Val Attributes, ReturnStructure = Undefined) Export
//	If ReturnStructure = Undefined Then
//		ReturnStructure = New Structure;
//	EndIf;
//	
//	If TypeOf(Attributes) = Type("Structure") Then
//		
//		For Each CollectionAttributes In Attributes Do
//			If TypeOf(Source[CollectionAttributes.Key]) = Type("FormDataCollection") Then
//				RowsArray = New Array;
//				For Each Row In Source[CollectionAttributes.Key] Do
//					RowsArray.Add(CreateValueStructureToPut(Row, CollectionAttributes.Value));
//				EndDo;
//				ReturnStructure.Insert(CollectionAttributes.Key, RowsArray);
//			EndIf;
//		EndDo;
//	ElsIf TypeOf(Attributes) = Type("Array") Then
//		For Each AttributeName In Attributes Do
//			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
//		EndDo;
//	ElsIf TypeOf(Attributes) = Type("String") Then
//		While Find(Attributes, ",") > 0 Do
//			
//			AttributeName = TrimAll(Left(Attributes, Find(Attributes, ",") - 1));
//			Attributes = Right(Attributes, StrLen(Attributes) - Find(Attributes, ","));
//			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
//			
//		EndDo;
//		If StrLen(Attributes) > 0 Then
//			
//			AttributeName = TrimAll(Attributes);
//			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
//			
//		EndIf;
//	EndIf;
//	
//	Return ReturnStructure;
//EndFunction

//Function GetNameFile(FileName) Export
//	TempNameFile = StrReplace(FileName, "/", "\");
//	While Find(TempNameFile, "\") > 0 Do
//		TempNameFile = Right(TempNameFile, StrLen(TempNameFile) - Find(TempNameFile, "\"));
//	EndDo;
//	Return TempNameFile;
//EndFunction

//Function GetZIPBinaryDataStructure(FileName, OriginalFileName = True, FileExtension = "") Export
//	
//	ReturnResult = New Structure("BinaryData, Password, FileName");
//	
//	#If Not WebClient Then
//		
//	TmpFile = New Array;
//	FullNameZIPTempFile = GetTempFileName("ZIP");
//	ReturnResult.FileName = GetNameFile(FullNameZIPTempFile);
//	ReturnResult.Password = String(New UUID);
//	
//	TempZIPFile = New ZipFileWriter(FullNameZIPTempFile, ReturnResult.Password);
//	If TypeOf(FileName) = Type("String") Then
//		If OriginalFileName Then
//			TempZIPFile.Add(FileName);
//		Else
//			If FileExtension = "" Then
//				tempFileName = GetTempFileName();
//			Else
//				tempFileName = GetTempFileName(FileExtension);
//			EndIf;
//			FileCopy(FileName, tempFileName);
//			TmpFile.Add(tempFileName);
//			TempZIPFile.Add(tempFileName);
//		EndIf;
//	ElsIf TypeOf(FileName) = Type("Array") Then
//		For Each File In FileName Do
//			If OriginalFileName Then
//				TempZIPFile.Add(File);
//			Else
//				If FileExtension = "" Then
//					tempFileName = GetTempFileName();
//				Else
//					tempFileName = GetTempFileName(FileExtension);
//				EndIf;
//				FileCopy(FileName, tempFileName);
//				TmpFile.Add(tempFileName);
//				TempZIPFile.Add(tempFileName);
//			EndIf;
//		EndDo;
//	EndIf;
//	TempZIPFile.Write();
//	
//	ReturnResult.BinaryData = New BinaryData(FullNameZIPTempFile);
//	DeleteFiles(FullNameZIPTempFile);
//	For Each DeleteNameFile In TmpFile Do
//		DeleteFiles(DeleteNameFile);
//	EndDo;
//		
//	#EndIf
//	
//	Return ReturnResult;
//	
//EndFunction

////File is MXL, XLS, XLSX, or ODS 
//Function GetSpreadsheetDocuments(FileName) Export
//	
//	ZIPBinaryData = GetZIPBinaryDataStructure(FileName);
//	Return CommonAtServer.GetSpreadsheetDocument(ZIPBinaryData);
//	
//EndFunction

//Procedure PushReportSettings(Val ReportMetadataName,Val CurrentVariantKey,Val Settings) Export
//    // Jack 29.05.2017	
//	//ReportStructure = New Structure;
//	//ReportStructure.Insert("ReportMetadataName",ReportMetadataName);
//	//ReportStructure.Insert("SettingsKey",CurrentVariantKey);
//	//ReportStructure.Insert("Settings",Settings);
//	//#If NOT ThickClientOrdinaryApplication Then
//	//ReportTempSettingStructure.Insert("Setting"+StrReplace(String(New UUID),"-",""),ReportStructure);
//	//#EndIf
//EndProcedure	

// Finding first tabular part row, that agree with filter.
//
// Returning values:
//  Tabular part row - finded row,
//  Undefined        - if the row was not founded.
//
Function FindTabularPartRow(TabularPart, RowFilterStructure) Export 
	
	RowsArray = TabularPart.FindRows(RowFilterStructure);
	
	If RowsArray.Count() = 0 Then
		Return Undefined;                  
	Else
		Return RowsArray[0];
	EndIf;
	
EndFunction // FindTabularPartRow()

//#Region SaaSLicenses

//Procedure SaasUsersCheck() Export
//	
//	SaaSCheckStructure = CommonAtServer.GetSaaSCheckStructure();	
//	SessionsCount = 0;
//	
//	For Each Session In SaaSCheckStructure.CurrentSessions Do
//		If Lower(Session.ApplicationName) = "1cv8"
//			OR Lower(Session.ApplicationName) = "1cv8c"
//			OR Lower(Session.ApplicationName) = "webclient" Then
//			SessionsCount = SessionsCount + 1;
//		EndIf;
//	EndDo;
//	
//	MessageText = Alerts.ParametrizeString(NStr("en = 'We’re sorry, but you’ve exceed the limit of users online (max %P1 users).
//                                                 |You can increase the limit at www.1c.pl after the login.'; pl = 'Przepraszamy, ale limit dostępnych online użytkowników został przekroczony (maks %P1 użytkowników). 
//                                                 |Możesz zwiększyć ilość użytkowników na portalu klienta na stronie www.1c.pl logując się na swoje konto.'; ru = 'Извините, но вы превысили количество допустимых онлайн пользователей (максимально %P1 пользователей).
//                                                 |Вы можете увеличить количество пользователей на сайте www.1c.pl после входа в личный кабинет.'"), New Structure("P1", SaaSCheckStructure.SaaSLicensesCount));
//	
//	If SessionsCount > SaaSCheckStructure.SaaSLicensesCount
//		AND NOT SaaSCheckStructure.IsAdministrator Then
//		ShowMessageBox(New NotifyDescription("CloseExcessSession", CommonAtClient), MessageText, 30);
//	EndIf;
//		
//EndProcedure

//Procedure CloseExcessSession(AdditionalParameters) Export
//	Terminate();
//EndProcedure

//#EndRegion

//Procedure BeforeExit(Answer, Parameters) Export
//	If Answer = DialogReturnCode.No Then
//		Return;
//	EndIf;
//	
//	ApplicationParameters.Insert("ShutDownSystem", TRUE);
//	
//	Exit();
//EndProcedure