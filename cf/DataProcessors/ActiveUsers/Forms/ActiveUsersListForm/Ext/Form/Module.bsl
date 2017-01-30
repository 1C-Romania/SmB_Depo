&AtClient
Var AdministrationParameters, RequestInfobaseAdministrationParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("ExclusiveModeSetupError") AND Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	Parameters.Property("NoticeOfClosure", NoticeOfClosure);
	
	InfobaseSessionNumber = InfobaseSessionNumber();
	ConditionalAppearance.Items[0].Filter.Items[0].RightValue = InfobaseSessionNumber;
	
	If CommonUse.FileInfobase()
		Or Not ((NOT CommonUseReUse.SessionWithoutSeparator() AND Users.InfobaseUserWithFullAccess())
		Or Users.InfobaseUserWithFullAccess(, True)) Then
		
		Items.EndSession.Visible = False;
		Items.TerminateSessionContext.Visible = False;
		
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		Items.UsersListDataSeparation.Visible = False;
	EndIf;
	
	SortingColumnName = "OperationStart";
	SortDirection = "Asc";
	
	FillConnectionFilterChoiceList();
	If Parameters.Property("FilterApplicationName") Then
		If Items.FilterApplicationName.ChoiceList.FindByValue(Parameters.FilterApplicationName) <> Undefined Then
			FilterApplicationName = Parameters.FilterApplicationName;
		EndIf;
	EndIf;
	
	FillUsersList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RequestInfobaseAdministrationParameters = True;
EndProcedure

&AtClient
Procedure OnClose()
	If NoticeOfClosure Then
		NoticeOfClosure = False;
		NotifyChoice(Undefined);
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilterApplicationNameOnChange(Item)
	FillList();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// THE ITEMS EVENT HANDLERS OF THE UsersList TABLE

&AtClient
Procedure UsersListSelection(Item, SelectedRow, Field, StandardProcessing)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EndSession(Command)
	
	SelectedRowsQuantity = Items.UsersList.SelectedRows.Count();
	
	If SelectedRowsQuantity = 0 Then
		
		ShowMessageBox(,NStr("en='Users for session end is not selected.';ru='Не выбраны пользователи для завершения сеансов.'"));
		Return;
		
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientWorkParameters.DataSeparationEnabled AND ClientWorkParameters.CanUseSeparatedData Then
		
		EndingSession = Items.UsersList.CurrentData.Session;
		
		If EndingSession = InfobaseSessionNumber Then
			ShowMessageBox(,NStr("en='It is impossible to end the current session. To exit the application, close the main application window.';ru='Невозможно завершить текущий сеанс. Для выхода из программы можно закрыть главное окно программы.'"));
			Return;
		EndIf;
		
		StandardProcessing = True;
		AlertAfterSessionEnd = New NotifyDescription(
		"AfterSessionEnd", ThisObject, New Structure("SessionNumber", EndingSession));
		
		EventHandlers = CommonUseClient.ServiceEventProcessor(
			"StandardSubsystems.UserSessions\OnSessionEnd");
		
		For Each Handler IN EventHandlers Do
			Handler.Module.OnSessionEnd(ThisObject, EndingSession, StandardProcessing, AlertAfterSessionEnd);
		EndDo;
		
	Else
		
		SelectedRowsQuantity = Items.UsersList.SelectedRows.Count();
		
		If SelectedRowsQuantity = 1 Then
			
			If Items.UsersList.CurrentData.Session = InfobaseSessionNumber Then
				ShowMessageBox(,NStr("en='It is impossible to end the current session. To exit the application, close the main application window.';ru='Невозможно завершить текущий сеанс. Для выхода из программы можно закрыть главное окно программы.'"));
				Return;
			EndIf;
			
		EndIf;
		
		If RequestInfobaseAdministrationParameters Then
			
			NotifyDescription = New NotifyDescription("EndSessionContinuation", ThisObject);
			FormTitle = NStr("en='Terminate session';ru='Завершить сеанс'");
			ExplanatoryInscription = NStr("en='To end the session it
		|is necessary to enter administration parameters of server cluster';ru='Для завершения сеанса
		|необходимо ввести параметры администрирования кластера серверов'");
			InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, False, True, AdministrationParameters, FormTitle, ExplanatoryInscription);
			
		Else
			
			EndSessionContinuation(AdministrationParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshExecute()
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLogMonitor()
	
	SelectedRows = Items.UsersList.SelectedRows;
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(,NStr("en='Select users to view the event log.';ru='Выберите пользователей для просмотра журнала регистрации.'"));
		Return;
	EndIf;
	
	FilterByUsers = New ValueList;
	For Each RowID IN SelectedRows Do
		UserRow = UsersList.FindByID(RowID);
		UserName = UserRow.UserName;
		If FilterByUsers.FindByValue(UserName) = Undefined Then
			FilterByUsers.Add(UserRow.UserName, UserRow.UserName);
		EndIf;
	EndDo;
	
	OpenForm("DataProcessor.EventLogMonitor.Form", New Structure("User", FilterByUsers));
	
EndProcedure

&AtClient
Procedure SortAscending()
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDescending()
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure OpenUser(Command)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersList.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersList.Session");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

EndProcedure

&AtClient
Procedure FillList()
	
	// To restore positions we will store the current session.
	CurrentSession = Undefined;
	CurrentData = Items.UsersList.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUsersList();
	
	// We restore the current string by stored session.
	If CurrentSession <> Undefined Then
		SearchStructure = New Structure;
		SearchStructure.Insert("Session", CurrentSession);
		FoundSessions = UsersList.FindRows(SearchStructure);
		If FoundSessions.Count() = 1 Then
			Items.UsersList.CurrentRow = FoundSessions[0].GetID();
			Items.UsersList.SelectedRows.Clear();
			Items.UsersList.SelectedRows.Add(Items.UsersList.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	
	Column = Items.UsersList.CurrentItem;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortingColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
	
EndProcedure

&AtServer
Procedure FillConnectionFilterChoiceList()
	ApplicationNames = New Array;
	ApplicationNames.Add("1CV8");
	ApplicationNames.Add("1CV8C");
	ApplicationNames.Add("WebClient");
	ApplicationNames.Add("Designer");
	ApplicationNames.Add("COMConnection");
	ApplicationNames.Add("WSConnection");
	ApplicationNames.Add("BackgroundJob");
	ApplicationNames.Add("SystemBackgroundJob");
	ApplicationNames.Add("SrvrConsole");
	ApplicationNames.Add("COMConsole");
	ApplicationNames.Add("JobScheduler");
	ApplicationNames.Add("Debugger");
	ApplicationNames.Add("OpenIDProvider");
	ApplicationNames.Add("RAS");
	
	ChoiceList = Items.FilterApplicationName.ChoiceList;
	For Each ApplicationName IN ApplicationNames Do
		ChoiceList.Add(ApplicationName, ApplicationPresentation(ApplicationName));
	EndDo;
EndProcedure

&AtServer
Procedure FillUsersList()
	
	UsersList.Clear();
	
	If Not CommonUseReUse.DataSeparationEnabled()
	 OR CommonUseReUse.CanUseSeparatedData() Then
		
		Users.FindAmbiguousInfobaseUsers(,);
	EndIf;
	
	InfobaseSessions = GetInfobaseSessions();
	ActiveUserCount = InfobaseSessions.Count();
	
	FilterApplicationNames = ValueIsFilled(FilterApplicationName);
	If FilterApplicationNames Then
		ApplicationNames = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FilterApplicationName, ",");
	EndIf;
	
	For Each InfobaseSession IN InfobaseSessions Do
		If FilterApplicationNames
			AND ApplicationNames.Find(InfobaseSession.ApplicationName) = Undefined Then
			ActiveUserCount = ActiveUserCount - 1;
			Continue;
		EndIf;
		
		UserRow = UsersList.Add();
		
		UserRow.Application   = ApplicationPresentation(InfobaseSession.ApplicationName);
		UserRow.OperationStart = InfobaseSession.SessionStarted;
		UserRow.Computer    = InfobaseSession.ComputerName;
		UserRow.Session        = InfobaseSession.SessionNumber;
		UserRow.Connection  = InfobaseSession.ConnectionNumber;
		
		If TypeOf(InfobaseSession.User) = Type("InfobaseUser")
		   AND ValueIsFilled(InfobaseSession.User.Name) Then
			
			UserRow.User        = InfobaseSession.User.Name;
			UserRow.UserName     = InfobaseSession.User.Name;
			UserRow.UserRef  = FindRefByUserID(
				InfobaseSession.User.UUID);
			
			If CommonUseReUse.DataSeparationEnabled() 
				AND Users.InfobaseUserWithFullAccess(, True) Then
				
				UserRow.DataSeparation = DataSeparationValuesToString(
					InfobaseSession.User.DataSeparation);
			EndIf;
			
		Else
			PropertiesOfUnspecified = UsersService.UnspecifiedUserProperties();
			UserRow.User       = PropertiesOfUnspecified.FullName;
			UserRow.UserName    = "";
			UserRow.UserRef = PropertiesOfUnspecified.Ref;
		EndIf;

		If InfobaseSession.SessionNumber = InfobaseSessionNumber Then
			UserRow.UserPictureNumber = 0;
		Else
			UserRow.UserPictureNumber = 1;
		EndIf;
		
	EndDo;
	
	UsersList.Sort(SortingColumnName + " " + SortDirection);
	
EndProcedure

&AtServer
Function DataSeparationValuesToString(DataSeparation)
	
	Result = "";
	Value = "";
	If DataSeparation.Property("DataArea", Value) Then
		Result = String(Value);
	EndIf;
	
	HasOtherSeparators = False;
	For Each Delimiter IN DataSeparation Do
		If Delimiter.Key = "DataArea" Then
			Continue;
		EndIf;
		If Not HasOtherSeparators Then
			If Not IsBlankString(Result) Then
				Result = Result + " ";
			EndIf;
			Result = Result + "(";
		EndIf;
		Result = Result + String(Delimiter.Value);
		HasOtherSeparators = True;
	EndDo;
	If HasOtherSeparators Then
		Result = Result + ")";
	EndIf;
	Return Result;
		
EndFunction

&AtServer
Function FindRefByUserID(ID)
	
	// There is no access to separate catalog from unseparated session.
	If CommonUseReUse.DataSeparationEnabled() 
		AND Not CommonUseReUse.CanUseSeparatedData() Then
		Return Undefined;
	EndIf;	
	
	Query = New Query;
	
	QueryTextPattern = "SELECT
					|	Ref AS Ref
					|FROM
					|	%1
					|WHERE
					|	InfobaseUserID = &ID";
					
	QueryByUsersText = 
			StringFunctionsClientServer.PlaceParametersIntoString(
					QueryTextPattern,
					"Catalog.Users");
	
	QueryTextForExternalUsers = 
			StringFunctionsClientServer.PlaceParametersIntoString(
					QueryTextPattern,
					"Catalog.ExternalUsers");
					
	Query.Text = QueryByUsersText;
	Query.Parameters.Insert("ID", ID);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Query.Text = QueryTextForExternalUsers;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Return Catalogs.Users.EmptyRef();
	
EndFunction

&AtClient
Procedure OpenUserFromList()
	
	CurrentData = Items.UsersList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	User = CurrentData.UserRef;
	If ValueIsFilled(User) Then
		OpenParameters = New Structure("Key", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			OpenForm("Catalog.Users.Form.ItemForm", OpenParameters);
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			OpenForm("Catalog.ExternalUsers.Form.ItemForm", OpenParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EndSessionContinuation(Result, AdditionalParameters = Undefined) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AdministrationParameters = Result;
	
	Message = "";
	SessionNumberToTerminate = Items.UsersList.CurrentData.Session;
	
	SessionsArray = New Array;
	For Each RowID IN Items.UsersList.SelectedRows Do
		
		SessionNumber = UsersList.FindByID(RowID).Session;
		
		If SessionNumber = InfobaseSessionNumber Then
			Continue;
		EndIf;
		
		SessionsArray.Add(SessionNumber);
		
	EndDo;
	
	SessionStructure = New Structure;
	SessionStructure.Insert("Property", "Number");
	SessionStructure.Insert("ComparisonType", ComparisonType.InList);
	SessionStructure.Insert("Value", SessionsArray);
	Filter = CommonUseClientServer.ValueInArray(SessionStructure);
	
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	
	Try
		If ClientConnectedViaWebServer Then
			DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
		Else
			ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
		EndIf;
	Except
		RequestInfobaseAdministrationParameters = True;
		Raise;
	EndTry;
	
	RequestInfobaseAdministrationParameters = False;
	
	AfterSessionEnd(DialogReturnCode.OK, New Structure("SessionNumbers", SessionsArray));
	
EndProcedure

&AtClient
Procedure AfterSessionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		If AdditionalParameters.Property("SessionNumbers")
			AND AdditionalParameters.SessionNumbers.Count() > 1 Then
			
			NotificationText = NStr("en='The %1 sessions is completed.';ru='Сеансы %1 завершены.'");
			SessionNumbers = StringFunctionsClientServer.RowFromArraySubrows(AdditionalParameters.SessionNumbers);
			NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText,
				SessionNumbers);
			ShowUserNotification(NStr("en='Sessions end';ru='Завершение сеансов'"),, NotificationText);
			
		Else
			
			NotificationText = NStr("en='The %1 session is completed.';ru='Сеанс %1 завершен.'");
			NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText,
			AdditionalParameters.SessionNumbers);
			ShowUserNotification(NStr("en='Terminate session';ru='Завершить сеанс'"),, NotificationText);
			
		EndIf;
		
		FillList();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
	
	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

#EndRegion
