////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

Var PropertiesStructure Export;

////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENT HANDLERS

Procedure BeforeWrite(Cancel)
	
	Message = "";
	
	AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation());
		
	Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,,Cancel);
	
	If IsBlankString(SettingsKey) Then
		SettingsKey = String(New UUID);
	EndIf;	
	
	If Cancel Then
		Alerts.AddAlert(Nstr("en='Setting""';pl='Ustawienie""';ru='Настройка""'") + " " + Description + " " + Nstr("en='""could not be write:';pl='""nie zostało zapisane';ru='""не была сохранена'") + Message,,Cancel,ThisObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS FOR OBJECT

Function GetAttributesValueTableForValidation() Export
	
	AttributesStructure = New Structure("Owner, Description");
	
	If NOT IsFolder Then
		AttributesStructure.Insert("SetupObject");
	EndIf;

	Return Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure, Enums.AlertType.Error);
	
EndFunction

Function ElementChecks(Cancel = Undefined) Export
	
	If NOT (IsInRole(Metadata.Roles.Role_SystemSettings) OR IsInRole(Metadata.Roles.Right_Administration_ConfigurationAdministration)) 
		AND Owner <> SessionParameters.CurrentUser Then
		Alerts.AddAlert( Nstr("en='User without administrative rights can save setting only for himself.';pl='Użytkownik bez administracyjnych uprawnień może zapisywać ustawienia jedynie dla siebie.';ru='Пользователь без прав администратора может сохранять только свои настройки.'"), Enums.AlertType.Error,Cancel,ThisObject);
	EndIf;	
	
EndFunction

Procedure OnCopy(CopiedObject)
	SettingsKey = New UUID;
	Owner = SessionParameters.CurrentUser;
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// MAIN PROGRAMM

PropertiesStructure = New Structure();

PropertiesStructure.Insert("DeletionMark", "Deletion mark");
PropertiesStructure.Insert("Owner",        "User-owner");
PropertiesStructure.Insert("Parent",        "Settings group");
PropertiesStructure.Insert("Description",    "Description settings");

For each Attribute In Metadata.Catalogs.SavedSettings.Attributes Do
	PropertiesStructure.Insert(Attribute.Name, Attribute.Presentation());
EndDo;
