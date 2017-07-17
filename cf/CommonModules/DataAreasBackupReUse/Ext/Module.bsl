
////////////////////////////////////////////////////////////////////////////////
// DataAreasBackupReUse.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns compliance of the russian field names
// of application system settings by English from XDTO package ZoneBackupControl of the service Manager.
// (type: {http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl}Settings).
//
// Returns:
// FixedMap.
//
Function RussianSettingsFieldsNamesToEnglishMap() Export
	
	Result = New Map;
	
	Result.Insert("CreateDailyBackup", "DailyCopiesForming");
	Result.Insert("CreateMonthlyBackup", "MonthlyCopiesForming");
	Result.Insert("CreateYearlyBackup", "AnnualCopiesForming");
	Result.Insert("BackupCreationTime", "CopiesFormingTime");
	Result.Insert("MonthlyBackupCreationDay", "MonthlyCopiesFormingMonthDate");
	Result.Insert("YearlyBackupCreationMonth", "AnnualCopiesFormingMonth");
	Result.Insert("YearlyBackupCreationDay", "AnnualCopiesFormingMonthDate");
	Result.Insert("KeepDailyBackups", "DailyCopiesAmount");
	Result.Insert("KeepMonthlyBackups", "MonthlyCopiesAmount");
	Result.Insert("KeepYearlyBackups", "AnnualCopiesAmount");
	Result.Insert("CreateDailyBackupOnUserWorkDaysOnly", "DailyCopiesFormingOnlyInUsersWorkDays");
	
	Return New FixedMap(Result);

EndFunction	

// Determines whether the application supports backup functionality.
//
// Returns:
// Boolean - True if the application supports backup functionality.
//
Function ServiceManagerSupportsBackup() Export
	
	SetPrivilegedMode(True);
	
	SupportedVersions = CommonUse.GetInterfaceVersions(
		Constants.InternalServiceManagerURL.Get(),
		Constants.ServiceManagerOfficeUserName.Get(),
		Constants.ServiceManagerOfficeUserPassword.Get(),
		"DataAreasBackup");
		
	Return SupportedVersions.Find("1.0.1.1") <> Undefined;
	
EndFunction

// Returns the backup control web service proxy.
// 
// Returns: 
// WSProxy.
// Proxy of service manager. 
// 
Function BackupControlProxy() Export
	
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager are not set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerAddress + "/ws/ZoneBackupControl?wsdl";
	UserName = Constants.ServiceManagerOfficeUserName.Get();
	UserPassword = Constants.ServiceManagerOfficeUserPassword.Get();
	
	Proxy = CommonUse.WSProxy(ServiceAddress, "http://www.1c.ru/SaaS/1.0/WS",
		"ZoneBackupControl", , UserName, UserPassword, 10);
		
	Return Proxy;
	
EndFunction

// It returns the subsystem name, which should
//  be used in the names of the registration log events.
//
// Return value: String.
//
Function SubsystemNameForEventLogMonitorEvents() Export
	
	Return Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Subsystems.DataAreasBackup.Name;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Background jobs

// Returns the name of the background job method of exporting the field to file.
//
// Returns:
// Row.
//
Function BackgroundBackupMethodName() Export
	
	Return "DataAreasBackup.ExportAreaToMSStorage";
	
EndFunction

// Returns the name of the background job of exporting the area to a file.
//
// Returns:
// Row.
//
Function BackgroundBackupName() Export
	
	Return NStr("en='Data area backup';ru='Резервное копирование области данных'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion
