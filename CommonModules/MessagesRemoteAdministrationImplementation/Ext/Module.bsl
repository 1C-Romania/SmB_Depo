////////////////////////////////////////////////////////////////////////////////
// GENERAL IMPLEMENTATION OF REMOTE ADMINISTRATION MESSAGES PROCESSING
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}UpdateUser.
//
// Parameters:
//  Name - String,
//  user name, FullName - String, full
//  user name, PasswordHash - String, password
//  saved value, ApplicationUserID - UUID,
//  ServiceUserID - UUID,
//  PhoneNumber - String, user
//  phone number, EmailAddress - String, user email
//  address, LanguageCode - String, user language code.
//
Procedure UpdateUser(Val Name, Val FullName, Val PasswordHash,
		Val IDUserApplications,
		Val ServiceUserID,
		Val PhoneNumber = "", Val EmailAddress = "",
		Val LanguageCode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	UserLanguage = GetLanguageByCode(LanguageCode);
	
	Mail = EmailAddress;
	
	Phone = PhoneNumber;
	
	EmailAddressStructure = GetEmailAddressStructure(Mail);
	
	BeginTransaction();
	Try
		If ValueIsFilled(IDUserApplications) Then
			
			DataAreaUser = Catalogs.Users.GetRef(IDUserApplications);
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.Users");
			LockItem.SetValue("Ref", DataAreaUser);
			Block.Lock();
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	Users.Ref AS Ref
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.ServiceUserID = &ServiceUserID";
			Query.SetParameter("ServiceUserID", ServiceUserID);
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.Users");
			Block.Lock();
			
			Result = Query.Execute();
			If Result.IsEmpty() Then
				DataAreaUser = Undefined;
			Else
				Selection = Result.Select();
				Selection.Next();
				DataAreaUser = Selection.Ref;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(DataAreaUser) Then
			UserObject = Catalogs.Users.CreateItem();
			UserObject.ServiceUserID = ServiceUserID;
		Else
			UserObject = DataAreaUser.GetObject();
		EndIf;
		
		UserObject.Description = FullName;
		
		RefreshEmailAddress(UserObject, Mail, EmailAddressStructure);
		
		UpdatePhone(UserObject, Phone);
		
		IBUserDescription = Users.NewInfobaseUserInfo();
		
		IBUserDescription.Name = Name;
		
		IBUserDescription.StandardAuthentication = True;
		IBUserDescription.OpenIDAuthentication = True;
		IBUserDescription.ShowInList = False;
		
		IBUserDescription.StoredPasswordValue = PasswordHash;
		
		IBUserDescription.Language = UserLanguage;
		
		IBUserDescription.Insert("Action", "Write");
		UserObject.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
		
		UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
		UserObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}PrepareApplication.
//
// Parameters:
//  DataAreaCode - number(7,0),
//  FromExport - Boolean, a flag showing creation of data area from the file with
//               data
//  exported from local mode (data_dump.zip), Variant - String, variant of initial data file
//  for data area, ExportID - UUID, file identifier for export to service manager storage.
//
Procedure PrepareDataArea(Val DataAreaCode, Val FromExporting, Val Variant, Val ExportID) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If Not ValueIsFilled(Constants.InfobaseUsageMode.Get()) Then
			MessageText = NStr("en='Infobase work mode is not installed';ru='Не установлен режим работы информационной базы'");
			Raise(MessageText);
		EndIf;
		
		Block = New DataLock;
		Item = Block.Add("InformationRegister.DataAreas");
		Block.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.Selected() Then
			If RecordManager.Status = Enums.DataAreaStatuses.Deleted Then
				MessagePattern = NStr("en='Data area %1 deleted';ru='Область данных %1 удалена'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.ToDelete Then
				MessagePattern = NStr("en='Data area %1 is being deleted';ru='Область данных %1 в процессе удаления'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.New Then
				MessagePattern = NStr("en='Data area %1 is getting prepared to be used';ru='Область данных %1 в процессе подготовки к использованию'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.Used Then
				MessagePattern = NStr("en='Data area %1 is used.';ru='Область данных %1 используется.'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			EndIf;
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.New;
		RecordManager.ExportID = ExportID;
		RecordManager.Repeat = 0;
		RecordManager.Variant = ?(FromExporting, "", Variant);
		
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		
		RecordManager.Write();
		
		MethodParameters = New Array;
		MethodParameters.Add(DataAreaCode);
		
		MethodParameters.Add(RecordManager.ExportID);
		If Not FromExporting Then
			MethodParameters.Add(Variant);
		EndIf;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName"    , "SaaSOperations.PrepareDataAreaToUse");
		JobParameters.Insert("Parameters"    , MethodParameters);
		JobParameters.Insert("Key"         , "1");
		JobParameters.Insert("DataArea", DataAreaCode);
		JobParameters.Insert("ExclusiveExecution", True);
		
		JobQueue.AddJob(JobParameters);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}DeleteApplication.
//
// Parameters:
//  DataAreaCode - number(7,0).
//
Procedure DeleteDataArea(Val DataAreaCode) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Item = Block.Add("InformationRegister.DataAreas");
		Block.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en='Data area %1 does not exist.';ru='Область данных %1 не существует.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaCode);
			Raise(MessageText);
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.ToDelete;
		RecordManager.Repeat = 0;
		
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		
		RecordManager.Write();
		
		MethodParameters = New Array;
		MethodParameters.Add(DataAreaCode);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName"    , "SaaSOperations.ClearDataArea");
		JobParameters.Insert("Parameters"    , MethodParameters);
		JobParameters.Insert("Key"         , "1");
		JobParameters.Insert("DataArea", DataAreaCode);
		
		JobQueue.AddJob(JobParameters);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationAccess.
//
// Parameters:
//  Name - String,
//  user name, PasswordHash - String, password
//  saved value, ServiceUserID - UUID,
//  AccessPermitted - Boolean, flag of access provision to
//  data area for user, LanguageCode - String, user language code.
//
Procedure SetAccessToDataArea(Val Name, Val PasswordHash,
		Val ServiceUserID,
		Val AccessPermitted, Val LanguageCode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		InfobaseUserID = CommonUse.ObjectAttributeValue(DataAreaUser, "InfobaseUserID");
		
		If AccessPermitted Then
			If Not ValueIsFilled(InfobaseUserID)
				OR InfobaseUsers.FindByUUID(InfobaseUserID) = Undefined Then
				
				InfobaseUserLanguage = GetLanguageByCode(LanguageCode);
				
				IBUserDescription = Users.NewInfobaseUserInfo();
				IBUserDescription.Insert("Action", "Write");
				IBUserDescription.Name = Name;
				IBUserDescription.Language = InfobaseUserLanguage;
				IBUserDescription.StoredPasswordValue = PasswordHash;
				IBUserDescription.StandardAuthentication = True;
				IBUserDescription.OpenIDAuthentication = True;
				IBUserDescription.ShowInList = False;
				
				UserObject = DataAreaUser.GetObject();
				UserObject.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
				UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
				UserObject.Write();
				
			EndIf;
			
		Else
			
			If ValueIsFilled(InfobaseUserID) Then
				IBUserDescription = New Structure;
				IBUserDescription.Insert("Action", "Delete");
				
				UserObject = DataAreaUser.GetObject();
				UserObject.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
				UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
				UserObject.Write();
			EndIf;
		EndIf;
			
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages
// with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetServiceManagerEndPoint.
//
// Parameters:
//  ExchangeNodeMessages - ExchangePlanRef.MessageExchange.
//
Procedure SetServiceManagerEndPoint(ExchangeNodeMessages) Export
	
	Constants.ServiceManagerEndPoint.Set(ExchangeNodeMessages);
	CommonUse.SetParametersOfInfobaseSeparation(True);
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetIBParams.
//
// Parameters:
//  Parameters - Structure containing values of parameters required to set for infobase.
//
Procedure SetInfobaseParameters(Parameters) Export
	
	BeginTransaction();
	Try
		ParameterTable = SaaSOperations.GetInfobaseParameterTable();
		
		ParametersToChange = New Structure;
		
		// Checking the correctness of parameters list.
		For Each KeyAndValue IN Parameters Do
			
			CurParameterString = ParameterTable.Find(KeyAndValue.Key, "Name");
			If CurParameterString = Undefined Then
				MessagePattern = NStr("en='Unknown parameter name %1';ru='Не известное имя параметра %1'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, KeyAndValue.Key);
				WriteLogEvent(NStr("en='RemoteAdministration.SetInfobaseParameters';ru='УдаленноеАдминистрирование.УстановитьПараметрыИБ'", 
					CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Warning, , , MessageText);
				Continue;
			ElsIf CurParameterString.WriteProhibition Then
				MessagePattern = NStr("en='Parameter %1 can be used for reading only';ru='Параметр %1 может использоваться только для чтения'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, KeyAndValue.Key);
				Raise(MessageText);
			EndIf;
			
			ParametersToChange.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndDo;
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.SaaS\OnSetInfobaseParameterValues");
		
		For Each Handler IN EventHandlers Do
			Handler.Module.OnSetInfobaseParameterValues(ParametersToChange);
		EndDo;
		
		SaaSOverridable.OnSetInfobaseParameterValues(ParametersToChange);
		
		For Each KeyAndValue IN ParametersToChange Do
			
			Constants[KeyAndValue.Key].Set(KeyAndValue.Value);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en='Installation of the IB parameters';ru='Установка параметров ИБ'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationParams.
//
// Parameters:
//  DataAreaCode - number(7,0),
//  DataAreaPresentation - String,
//  DataAreaTimeZone - String.
//
Procedure SetDataAreaParameters(Val DataAreaCode,
		Val DataAreaPresentation,
		Val DataAreaTimeZone = Undefined) Export
	
	ExternalExclusiveMode = ExclusiveMode();
	
	If Not ExternalExclusiveMode Then
		SaaSOperations.LockCurrentDataArea();
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		RefreshParametersOfCurrentDataArea(DataAreaPresentation, DataAreaTimeZone);
		
		If Not IsBlankString(DataAreaPresentation) Then
			RefreshPredefinedNodeProperties(DataAreaPresentation);
		EndIf;
		
		CommitTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
	Except
		
		RollbackTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
		Raise;
		
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  ServiceUserID - UUID,
//  AccessPermitted - Boolean, flag of access provision to data area for user,
//
Procedure SetDataAreaFullAccess(Val ServiceUserID, Val AccessPermitted) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		If UsersService.BanEditOfRoles()
			AND CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
			AccessControlModuleServiceSaaS = CommonUse.CommonModule("AccessManagementServiceSaaS");
			AccessControlModuleServiceSaaS.SetUserIdentityToAdministratorsGroup(DataAreaUser, AccessPermitted);
			
		Else
			
			IBUser = GetInfobaseUserByDataAreaUser(DataAreaUser);
			
			FullAccessRole = Metadata.Roles.FullRights;
			If AccessPermitted Then
				If Not IBUser.Roles.Contains(FullAccessRole) Then
					IBUser.Roles.Add(FullAccessRole);
				EndIf;
			Else
				If IBUser.Roles.Contains(FullAccessRole) Then
					IBUser.Roles.Delete(FullAccessRole);
				EndIf;
			EndIf;
			
			UsersService.WriteInfobaseUser(IBUser);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetDefaultUserRights.
//
// Parameters:
//  ServiceUserID - UUID
//
Procedure SetDefaultUserRights(Val ServiceUserID) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.SaaS\OnDefaultRightSet");
		For Each Handler IN EventHandlers Do
			Handler.Module.OnDefaultRightSet(DataAreaUser);
		EndDo;
		
		SaaSOverridable.SetDefaultRights(DataAreaUser);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationsRating.
//
// Parameters:
//  RatingTable - ValuesTable containing the rating of data areas activity, columns:
//    DataArea - number(7,0),
//    Rating - number(7,0),
//  Replace - Boolean, flag of replacement of existing records in activity rating of data areas.
//
Procedure SetDataAreaRating(Val RatingTable, Val ToReplace) Export
	
	SetPrivilegedMode(True);
	
	Set = InformationRegisters.DataAreasActivityRating.CreateRecordSet();
	
	If ToReplace Then
		Set.Load(RatingTable);
		Set.Write();
	Else
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.DataAreasActivityRating");
		LockItem.DataSource = RatingTable;
		LockItem.UseFromDataSource("DataAreaAuxiliaryData", "DataAreaAuxiliaryData");
		BeginTransaction();
		
		Try
			Block.Lock();
			
			For Each RatingRow IN RatingTable Do
				Set.Clear();
				Set.Filter.DataAreaAuxiliaryData.Set(RatingRow.DataAreaAuxiliaryData);
				Record = Set.Add();
				FillPropertyValues(Record, RatingRow);
				Set.Write();
			EndDo;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

// Processor of incoming messages with type http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}BindApplication.
//
// Parameters:
//  Parameters - Structure containing values of parameters required to set for data area.
//
Procedure DataAreaAttach(Parameters) Export
	
	ExternalExclusiveMode = ExclusiveMode();
	
	If Not ExternalExclusiveMode Then
		SaaSOperations.LockCurrentDataArea();
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Setting the parameters of data area.
		Block = New DataLock;
		Item = Block.Add("InformationRegister.DataAreas");
		Block.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en='Data area %1 does not exist.';ru='Область данных %1 не существует.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Parameters.Zone);
			Raise(MessageText);
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.Used;
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		RecordManager.Write();
		
		RefreshParametersOfCurrentDataArea(Parameters.Presentation, Parameters.TimeZone);
		
		// Creating administrators in the area.
		For Each UserDetails IN Parameters.UsersList.Item Do
			UserLanguage = GetLanguageByCode(UserDetails.Language);
			
			Mail = "";
			Phone = "";
			If ValueIsFilled(UserDetails.EMail) Then
				Mail = UserDetails.EMail;
			EndIf;
			
			If ValueIsFilled(UserDetails.Phone) Then
				Phone = UserDetails.Phone;
			EndIf;
			
			EmailAddressStructure = GetEmailAddressStructure(Mail);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|    Users.Ref AS Ref
			|FROM
			|    Catalog.Users AS Users
			|WHERE
			|    Users.ServiceUserID = &ServiceUserID";
			Query.SetParameter("ServiceUserID", UserDetails.UserServiceID);
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.Users");
			Block.Lock();
			
			Result = Query.Execute();
			If Result.IsEmpty() Then
				DataAreaUser = Undefined;
			Else
				Selection = Result.Select();
				Selection.Next();
				DataAreaUser = Selection.Ref;
			EndIf;
			
			If Not ValueIsFilled(DataAreaUser) Then
				UserObject = Catalogs.Users.CreateItem();
				UserObject.ServiceUserID = UserDetails.UserServiceID;
			Else
				UserObject = DataAreaUser.GetObject();
			EndIf;
			
			UserObject.Description = UserDetails.FullName;
			
			RefreshEmailAddress(UserObject, Mail, EmailAddressStructure);
			
			UpdatePhone(UserObject, Phone);
			
			IBUserDescription = Users.NewInfobaseUserInfo();
			
			IBUserDescription.Name = UserDetails.Name;
			
			IBUserDescription.StandardAuthentication = True;
			IBUserDescription.OpenIDAuthentication = True;
			IBUserDescription.ShowInList = False;
			
			IBUserDescription.StoredPasswordValue = UserDetails.StoredPasswordValue;
			
			IBUserDescription.Language = UserLanguage;
			
			Roles = New Array;
			Roles.Add("FullRights");
			IBUserDescription.Roles = Roles;
			
			IBUserDescription.Insert("Action", "Write");
			UserObject.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
			
			UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
			UserObject.Write();
			
			DataAreaUser = UserObject.Ref;
			
			If UsersService.BanEditOfRoles()
				AND CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
				AccessControlModuleServiceSaaS = CommonUse.CommonModule("AccessManagementServiceSaaS");
				AccessControlModuleServiceSaaS.SetUserIdentityToAdministratorsGroup(DataAreaUser, True);
			EndIf;
		EndDo;
		
		If Not IsBlankString(Parameters.Presentation) Then
			RefreshPredefinedNodeProperties(Parameters.Presentation);
		EndIf;
		
		Message = MessagesSaaS.NewMessage(MessageRemoteAdministratorControlInterface.MessageDataAreaIsReadyForUse());
			Message.Body.Zone = Parameters.Zone;
		
		MessagesSaaS.SendMessage(Message, SaaSReUse.ServiceManagerEndPoint(), True);
		
		CommitTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
	Except
		
		RollbackTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
		Raise;
		
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GetLanguageByCode(Val LanguageCode)
	
	If ValueIsFilled(LanguageCode) Then
		
		For Each Language IN Metadata.Languages Do
			If Language.LanguageCode = LanguageCode Then
				Return Language.Name;
			EndIf;
		EndDo;
		
		MessagePattern = NStr("en='Unsupported language code: %1';ru='Неподдерживаемый код языка: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Language);
		Raise(MessageText);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

Function GetEmailAddressStructure(Val EmailAddress)
	
	If ValueIsFilled(EmailAddress) Then
		
		Try
			EmailAddressStructure = CommonUseClientServer.ParseStringWithPostalAddresses(EmailAddress);
		Except
			MessagePattern = NStr("en='Incorrect email address is specified:"
"%1 Error: %2';ru='Указан некорректный адрес"
"электронной почты: %1 Ошибка: %2'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				EmailAddress, ErrorInfo().Definition);
			Raise(MessageText);
		EndTry;
		
		Return EmailAddressStructure;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Procedure RefreshEmailAddress(Val UserObject, Val Address, Val EmailAddressStructure)
	
	CIKind = Catalogs.ContactInformationTypes.UserEmail;
	
	TabularSectionRow = UserObject.ContactInformation.Find(CIKind, "Kind");
	If EmailAddressStructure = Undefined Then
		If TabularSectionRow <> Undefined Then
			UserObject.ContactInformation.Delete(TabularSectionRow);
		EndIf;
	Else
		If TabularSectionRow = Undefined Then
			TabularSectionRow = UserObject.ContactInformation.Add();
			TabularSectionRow.Type = CIKind;
		EndIf;
		TabularSectionRow.Type = Enums.ContactInformationTypes.EmailAddress;
		TabularSectionRow.Presentation = Address;
		
		If EmailAddressStructure.Count() > 0 Then
			TabularSectionRow.EMail_Address = EmailAddressStructure[0].Address;
			
			Pos = Find(TabularSectionRow.EMail_Address, "@");
			If Pos <> 0 Then
				TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EMail_Address, Pos + 1);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure UpdatePhone(Val UserObject, Val Phone)
	
	CIKind = Catalogs.ContactInformationTypes.UserPhone;
	
	TabularSectionRow = UserObject.ContactInformation.Find(CIKind, "Kind");
	If TabularSectionRow = Undefined Then
		TabularSectionRow = UserObject.ContactInformation.Add();
		TabularSectionRow.Type = CIKind;
	EndIf;
	TabularSectionRow.Type = Enums.ContactInformationTypes.Phone;
	TabularSectionRow.Presentation = Phone;
	
EndProcedure

Function GetAreaUserByServiceUserID(Val ServiceUserID)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.ServiceUserID = &ServiceUserID";
	Query.SetParameter("ServiceUserID", ServiceUserID);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.Users");
	
	BeginTransaction();
	Try
		Block.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		MessagePattern = NStr("en='User with the service user ID %1 has not been found';ru='Не найден пользователь с идентификатором пользователя сервиса %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ServiceUserID);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function GetInfobaseUserByDataAreaUser(Val DataAreaUser)
	
	InfobaseUserID = CommonUse.ObjectAttributeValue(DataAreaUser, "InfobaseUserID");
	IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
	If IBUser = Undefined Then
		MessagePattern = NStr("en='For the data area user with ID %1 an infobase user does not exist';ru='Для пользователя области данных с идентификатором %1 не существует пользователя информационной базы'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DataAreaUser.UUID());
		Raise(MessageText);
	EndIf;
	
	Return IBUser;
	
EndFunction

Procedure RefreshParametersOfCurrentDataArea(Val Presentation, Val TimeZone)
	
	Constants.DataAreaPresentation.Set(Presentation);
	
	If ValueIsFilled(TimeZone) Then
		SetInfobaseTimeZone(TimeZone);
	Else
		SetInfobaseTimeZone();
	EndIf;
	
	Constants.DataAreaTimeZone.Set(TimeZone);
	
EndProcedure

Procedure RefreshPredefinedNodeProperties(Val Description)
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		If DataExchangeReUse.ExchangePlanUsedSaaS(ExchangePlan.Name) Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			NodeProperties = CommonUse.ObjectAttributesValues(ThisNode, "Code, description");
			
			If IsBlankString(NodeProperties.Code) Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Code = ExchangePlanNodeCodeInService(SaaSOperations.SessionSeparatorValue());
				ThisNodeObject.Description = Description;
				ThisNodeObject.Write();
				
			ElsIf NodeProperties.Description <> Description Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Description = Description;
				ThisNodeObject.Write();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// It generates the exchange plan node code for the specified data area.
//
// Parameters:
// DataAreaNumber - Number - Separator value. 
//
// Returns:
// String - Exchange plan node code for the specified area. 
//
Function ExchangePlanNodeCodeInService(Val DataAreaNumber) Export
	
	If TypeOf(DataAreaNumber) <> Type("Number") Then
		Raise NStr("en='Inccorect number parameter type [1].';ru='Неправильный тип параметра номер [1].'");
	EndIf;
	
	Result = "S0[DataAreaNumber]";
	
	Return StrReplace(Result, "[DataAreaNumber]", Format(DataAreaNumber, "ND=7; NLZ=; NG=0"));
	
EndFunction

#EndRegion
