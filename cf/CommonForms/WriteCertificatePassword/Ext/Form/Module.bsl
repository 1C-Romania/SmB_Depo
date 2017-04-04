
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Certificate = Parameters.Certificate;
	Properties = CommonUse.ObjectAttributesValues(Certificate,
		"CertificateData, EnhancedProtectionPrivateKey, User, AddedByBy, Application");
	
	FillPropertyValues(ThisObject, Properties);
	CertificateData = CertificateData.Get();
	
	If EnhancedProtectionPrivateKey Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	BankApplications.BankApplication
		|FROM
		|	InformationRegister.BankApplications AS BankApplications
		|WHERE
		|	BankApplications.DSCertificate = &DSCertificate";
	
	Query.SetParameter("DSCertificate", Certificate);
	Selection = Query.Execute().Select();
	
	BankApplication = Undefined;
	While Selection.Next() Do
		BankApplication = Selection.BankApplication;
	EndDo;
	
	If Not (ValueIsFilled(Application) OR ValueIsFilled(BankApplication)) Then
		Return;
	EndIf;
	
	RightToWritePassword = RightToWritePassword();
	
	SetPrivilegedMode(True);
	Data = Constants.EDOperationContext.Get().Get();
	SetPrivilegedMode(False);
	
	If TypeOf(Data) <> Type("Map") Then
		Data = New Map;
	EndIf;
	
	Properties = Data.Get(Certificate);
	PasswordIsSet = False;
	
	If TypeOf(Properties) = Type("Structure")
	   AND Properties.Property("Password") Then
		
		PasswordIsSet = True;
		If Properties.Password <> Undefined Then
			Password = "********";
		EndIf;
		Properties.Property("User", User);
	Else
		User = Users.CurrentUser();
	EndIf;
	
	Items.FormDeletePassword.Enabled = PasswordIsSet;
	SetLableTitleAndCommandMarkAvailableToAll();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If EnhancedProtectionPrivateKey Then
		ShowMessageBox(,
			NStr("en='Certificate has a strong protection of a private key.
		|In this case, the electronic signature and encryption is
		|requesting a password and 1C:Enterprise application should pass a blank password to prevent error.
		|
		|Unable to remember and write password.';ru='У сертификата установлена усиленная защита закрытого ключа.
		|В таком случае пароль запрашивает программа электронной подписи и шифрования,
		|а программа 1С:Предприятия должна передать пустой пароль, чтобы не было ошибки.
		|
		|Запоминание и запись пароля невозможны'"));
		Cancel = True;
		Return;
	EndIf;
	
	If Not (ValueIsFilled(Application) OR ValueIsFilled(BankApplication)) Then
		ShowMessageBox(,
			NStr("en='Certificate does not have application for a private key.
		|Unable to verify the password before writing.';ru='У сертификата не указана программа для закрытого ключа.
		|Невозможно проверить пароль перед записью.'"));
		Cancel = True;
		Return;
	EndIf;
	
	If Not RightToWritePassword Then
		ShowMessageBox(, ErrorDescriptionAccessRights());
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PasswordOnChange(Item)
	
	PasswordChanged = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DeletePassword(Command)
	
	DeletePasswordAtServer();
	
EndProcedure

&AtClient
Procedure WritePassword(Command)
	
	ErrorDescription = "";
	
	If Not PasswordChanged AND ValueIsFilled(Password)
		OR Not ValueIsFilled(Application) AND ValueIsFilled(BankApplication) Then
		WritePasswordAtServer();
		Return;
	EndIf;
	
	If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		If Not CheckPasswordAndWrite(ErrorDescription) Then
			ErrorAtClientDescription = "";
			If CheckPassword(ErrorAtClientDescription) Then
				WritePasswordAtServer();
			Else
				ErrorDescription =
					  NStr("en='ON SERVER:';ru='НА СЕРВЕРЕ:'")
					+ Chars.LF + Chars.LF + ErrorDescription
					+ Chars.LF + Chars.LF
					+ NStr("en='ON COMPUTER:';ru='НА КОМПЬЮТЕРЕ:'")
					+ Chars.LF + Chars.LF + ErrorAtClientDescription;
			EndIf;
		EndIf;
	Else
		If CheckPassword(ErrorDescription) Then
			WritePasswordAtServer();
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		ShowMessageBox(, TrimAll(ErrorDescription));
	EndIf;
	
EndProcedure

&AtClient
Procedure PasswordAvailableToAll(Command)
	
	PasswordAvailableToAllAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure DeletePasswordAtServer()
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.EDOperationContext");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Data = Constants.EDOperationContext.Get().Get();
		If TypeOf(Data) = Type("Map") Then
			If Data.Get(Certificate) <> Undefined Then
				Data.Delete(Certificate);
			EndIf;
		EndIf;
		ValueManager = Constants.EDOperationContext.CreateValueManager();
		ValueManager.Value = New ValueStorage(Data);
		InfobaseUpdate.WriteData(ValueManager);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SetPrivilegedMode(False);
	
	Items.FormDeletePassword.Enabled = False;
	User = Users.CurrentUser();
	Password = "";
	PasswordChanged = False;
	
EndProcedure

&AtClient
Function CheckPassword(ErrorDescription)
	
	Return CheckSigning(ThisObject, Application, CertificateData, Password, ErrorDescription, DigitalSignatureClient);
	
EndFunction

&AtServer
Function CheckPasswordAndWrite(ErrorDescription)
	
	Success = CheckSigning(ThisObject, Application, CertificateData, Password, ErrorDescription, DigitalSignature);
	
	If Success Then
		WritePasswordAtServer();
	EndIf;
	
	Return Success;
	
EndFunction

&AtClientAtServerNoContext
Function CheckSigning(Form, Application, CertificateData, Password, ErrorDescription, Module)
	
	Certificate = New CryptoCertificate(CertificateData);
	
	CryptoManager = Module.CryptoManager("Signing", False, ErrorDescription, Application);
	If CryptoManager = Undefined Then
		Return False;
	EndIf;
	
	CryptoManager.PrivateKeyAccessPassword = Password;
	Try
		CryptoManager.Sign(CertificateData, Certificate);
	Except
		ErrorInfo = ErrorInfo();
		ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
			+ StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Unable to check the signing using the %1 application because
		|of: %2';ru='Не удалось пройти проверку подписания с помощью
		|программы %1 по причине: %2'"),
				Application,
				BriefErrorDescription(ErrorInfo));
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

&AtServer
Function WritePasswordAtServer()
	
	If Not RightToWritePassword() Then
		Raise ErrorDescriptionAccessRights();
	EndIf;
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.EDOperationContext");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Data = Constants.EDOperationContext.Get().Get();
		If TypeOf(Data) <> Type("Map") Then
			Data = New Map;
		EndIf;
		If PasswordChanged OR Not ValueIsFilled(Password) Then
			Properties = New Structure;
			Properties.Insert("Password", Password);
		Else
			Properties = Data.Get(Certificate);
			If TypeOf(Properties) <> Type("Structure")
			 Or Not Properties.Property("Password")
			 Or Not TypeOf(Properties.Password) = Type("String") Then
				
				Raise NStr("en='Enter the password again.';ru='Введите пароль повторно.'");
			EndIf;
		EndIf;
		Properties.Insert("User", User);
		Data.Insert(Certificate, Properties);
		ValueManager = Constants.EDOperationContext.CreateValueManager();
		ValueManager.Value = New ValueStorage(Data);
		InfobaseUpdate.WriteData(ValueManager);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Items.FormDeletePassword.Enabled = True;
	Password = "********";
	PasswordChanged = False;
	
	Return True;
	
EndFunction

&AtServer
Function RightToWritePassword()
	
	If Users.InfobaseUserWithFullAccess() Then
		Return True;
	EndIf;
	
	Properties = CommonUse.ObjectAttributesValues(Certificate, "User, AddedBy");
	If Properties.AddedBy = Users.CurrentUser()
	 Or Properties.User = Users.CurrentUser() Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtClientAtServerNoContext
Function ErrorDescriptionAccessRights()
	
	Return
		NStr("en='You have no right to write password.
		|
		|Writing of a password can be performed
		|by the user specified in the Uder and Added fields of the certificate or administrator.';ru='Недостаточно прав для записи пароля.
		|
		|Запись пароля может сделать
		|пользователь, указанный в полях сертификата ""Пользователь"" и ""Добавил"" или администратор.'");
	
EndFunction

&AtServer
Procedure PasswordAvailableToAllAtServer()
	
	If Items.PasswordUsersAvailableToAll.Check Then
		User = Users.CurrentUser();
	Else
		User = Catalogs.Users.EmptyRef();
	EndIf;
	SetLableTitleAndCommandMarkAvailableToAll();
	
EndProcedure

&AtServer
Procedure SetLableTitleAndCommandMarkAvailableToAll()
	
	If ValueIsFilled(User) Then
		Items.LabelAvailableToUser.Title = NStr("en='The password is available to user:';ru='Пароль доступен пользователю:'")
			+ " " + User;
	Else
		Items.LabelAvailableToUser.Title = NStr("en='The password is available to all users.';ru='Пароль доступен всем пользователям.'")
	EndIf;
	Items.PasswordUsersAvailableToAll.Check = Not ValueIsFilled(User);
	
EndProcedure

#EndRegion
