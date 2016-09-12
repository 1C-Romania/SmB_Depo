////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", safe mode extension.
// Procedures and functions with repeated use of returned values.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns an array of methods that can
// be run by the safe mode expansion.
//
// Return values: Array(String).
//
Function GetAllowedMethods() Export
	
	Result = New Array();
	
	// AdditionalReportsAndDataProcessorsInSafeMode
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.XMLReaderFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.XMLWriterToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.HTMLReadFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.RecordHTMLToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.FastInfosetReadingFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.RecordFastInfosetToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.CreateComObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ConnectExternalComponentFromCommonConfigurationTemplate");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ConnectExternalComponentFromConfigurationTemplate");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.GetFileFromExternalObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.TransferFileToExternalObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.GetFileFromInternet");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ImportFileInInternet");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.WSConnection");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.PostingDocuments");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.WriteObjects");
	// AdditionalReportsAndDataProcessorsInSafeMode
	
	// AdditionalReportsAndDataProcessorsInSafeModeServerCall
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.DocumentTextFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.TextDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.SpreadsheetDocumentFormBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.TabularDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.FormattedDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.BinaryDataRow");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.StringToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.UnpackArchive");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.PackFilesInArchive");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.ExecuteScriptInSafeMode");
	// End AdditionalReportsAndDataProcessorsInSafeModeServerCall
	
	Return New FixedArray(Result);
	
EndFunction

// Returns a dictionary of permissions additional reports and
// data processors kinds synonyms for and their parameters (for display in the user interface).
//
// Returns:
//  FixedMap:
//    Key - XDTOType corresponding
//    permission kind, Value - Structure, keys:
//      Presentation - String, brief presentation type
//      permissions, Description - String, detailed description
//      of permission kind, Parameters - ValueTable, columns:
//        Name - String, property name that
//        is defined for XDTOType, Description - String, description of the permission
//          parameter consequences for
//        the specified parameter value, AnyValueDescription - String, description of
//          the permission parameter consequences for unspecified parameter value.
//
Function Dictionary() Export
	
	Result = New Map();
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	Presentation = NStr("en='Receiving the data from the Internet';ru='Получение данных из сети Интернет'");
	Definition = NStr("en='Additional report or data processor will be allowed to receive data from the Internet';ru='Дополнительному отчету или обработке будет разрешено получать данные из сети Интернет'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "Host", NStr("en='from server %1';ru='с сервера %1'"), NStr("en='from any server';ru='с любого сервера'"));
	AddParameter(Parameters, "Protocol", NStr("en='via protocol %1';ru='по протоколу %1'"), NStr("en='via any protocol';ru='по любому протоколу'"));
	AddParameter(Parameters, "Port", NStr("en='using port %1';ru='через порт %1'"), NStr("en='using any port';ru='через любой порт'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.GetDataTypeOfInternet(),
		New Structure(
			"Presentation,Definition,Parameters",
			Presentation,
			Definition,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("en='Data transfer to the Internet';ru='Передача данных в сеть Интернет'");
	Definition = NStr("en='Additional report or processing will be allowed to send the data to the Internet network';ru='Дополнительному отчету или обработке будет разрешено отправлять данные в сеть Интернет'");
	Effects = NStr("en='Warning! Data sending potentially can"
"used by an additional report or data processor for"
"acts that are not alleged by administrator of infobases."
""
"Use this additional report or data processor only if you trust"
"the developer and control restriction (server, protocol and port),"
"attached to issued permissions.';ru='Внимание! Отправка данных потенциально может использоваться дополнительным"
"отчетом или обработкой для совершения действий, не предполагаемых администратором"
"информационной базы."
""
"Используйте данный дополнительный отчет или обработку только в том случае, если Вы доверяете"
"ее разработчику и контролируйте ограничения (сервер, протокол и порт), накладываемые на"
"выданные разрешения.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "Host", NStr("en='to server %1';ru='на сервер %1'"), NStr("en='on any server';ru='на любой сервера'"));
	AddParameter(Parameters, "Protocol", NStr("en='via protocol %1';ru='по протоколу %1'"), NStr("en='via any protocol';ru='по любому протоколу'"));
	AddParameter(Parameters, "Port", NStr("en='using port %1';ru='через порт %1'"), NStr("en='using any port';ru='через любой порт'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfTransferDataOnInternet(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	Presentation = NStr("en='References to the web services in the Internet';ru='Обращение к веб-сервисам в сети Интернет'");
	Definition = NStr("en='Additional report or data processor will be permitted to address the web-services located in the Internet (in this case, additional report or data processor can receive and transfer information from the Internet).';ru='Дополнительному отчету или обработке будет разрешено обращаться к веб-сервисам, расположенным в сети Интернет (при этом возможно как получение дополнительным отчетом или обработкой информации из сети Интернет, так и передача.'");
	Effects = NStr("en='Warning! Appeal to web services potentially"
"can be used by an additional report or data"
"processor for actions that are not alleged by infobases administrator."
""
"Use this additional report or data processor only if you"
"trust the developer and control restriction (connection address), attached"
"to issued permissions.';ru='Внимание! Обращение к веб-сервисам потенциально может использоваться дополнительным"
"отчетом или обработкой для совершения действий, не предполагаемых администратором"
"информационной базы."
""
"Используйте данный дополнительный отчет или обработку только в том случае, если Вы доверяете"
"ее разработчику и контролируйте ограничения (адрес подключения), накладываемые на"
"выданные разрешения.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "WsdlDestination", NStr("en='by address %1';ru='по адресу %1'"), NStr("en='by any address';ru='по любому адресу'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeWSConnection(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	Presentation = NStr("en='Creating COM-object';ru='Создание COM-объекта'");
	Definition = NStr("en='An additional report or processing will be allowed to use the mechanisms of external software using the COM-connection';ru='Дополнительному отчету или обработке будет разрешено использовать механизмы внешнего программного обеспечения с помощью COM-соединения'");
	Effects = NStr("en='Warning! Use of thirdparty software funds can"
"be used by an additional report or data processor for"
"actions that are not alleged by infobase administrator, and also for"
"unauthorized circumvention of the restrictions imposed by the additional processing in safe mode."
""
"Use this additional report or data processor only if"
"you trust the developer and control restriction (application ID),"
"attached to issued permissions.';ru='Внимание! Использование средств стороннего программного обеспечения может использоваться"
"дополнительным отчетом или обработкой для совершения действий, не предполагаемых администратором"
"информационной базы, а также для несанкционированного обхода ограничений, накладываемых на дополнительную обработку"
"в безопасном режиме."
""
"Используйте данный дополнительный отчет или обработку только в том случае, если Вы доверяете"
"ее разработчику и контролируйте ограничения (программный идентификатор), накладываемые на"
"выданные разрешения.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "ProgId", NStr("en='with application ID %1';ru='с программным идентификатором %1'"), NStr("en='with any application ID';ru='с любым программным идентификатором'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeCreatingCOMObject(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	Presentation = NStr("en='External component object creation';ru='Создание объекта внешней компоненту'");
	Definition = NStr("en='The additional report or processing will be allowed to use the mechanisms of the external software using the creation of the external component object that is provided in the configuration template';ru='Дополнительному отчету или обработке будет разрешено использовать механизмы внешнего программного обеспечения с помощью создания объекта внешней компоненты, поставляемой в макете конфигурации'");
	Effects = NStr("en='Warning! Use of thirdparty software funds can"
"be used by an additional report or data processor for"
"actions that are not alleged by infobase administrator, and also for"
"unauthorized circumvention of the restrictions imposed by the additional processing in safe mode."
""
"Use this additional report or data processor only if you"
"trust the developer and control restriction (template name, from which connection"
"is external component), attached to issued permissions.';ru='Внимание! Использование средств стороннего программного обеспечения может использоваться"
"дополнительным отчетом или обработкой для совершения действий, не предполагаемых администратором"
"информационной базы, а также для несанкционированного обхода ограничений, накладываемых на дополнительную обработку"
"в безопасном режиме."
""
"Используйте данный дополнительный отчет или обработку только в том случае, если Вы доверяете"
"ее разработчику и контролируйте ограничения (имя макета, из которого выполняется подключение внешней"
"компоненты), накладываемые на выданные разрешения.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "TemplateName", NStr("en='from template %1';ru='из макета %1'"), NStr("en='from any template';ru='из любого макета'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfConnectionOfExternalComponents(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	Presentation = NStr("en='Receiving of files from external object';ru='Получение файлов из внешнего объекта'");
	Definition = NStr("en='The additional report or processing will be allowed to receive the files out of the external software (e.g. using COM-connection or the external component)';ru='Дополнительному отчету или обработке будет разрешено получать файлы из внешнего программного обеспечения (например, с помощью COM-соединения или внешней компоненты)'");
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.GetFileTypeFromExternalObject(),
		New Structure(
			"Presentation,Description",
			Presentation,
			Definition));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	Presentation = NStr("en='Files transfer to an external object';ru='Передача файлов во внешний объект'");
	Definition = NStr("en='The additional report or processing will be allowed to transfer the files to the external software (e.g. using COM-connection or the external component)';ru='Дополнительному отчету или обработке будет разрешено передавать файлы во внешнее программное обеспечение (например, с помощью COM-соединения или внешней компоненты)'");
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeFileTransferIntoExternalObject(),
		New Structure(
			"Presentation,Description",
			Presentation,
			Definition));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("en='Documents posting';ru='Проведение документов'");
	Definition = NStr("en='Additional report or processing will be permitted to modify the documents posting status';ru='Дополнительному отчету или обработке будет разрешено изменять состояние проведенности документов'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "DocumentType", NStr("en='documents with type %1';ru='документы с типом %1'"), NStr("en='any documents';ru='любые документы'"));
	AddParameter(Parameters, "Action", NStr("en='Permitted action: %1';ru='разрешенное действие: %1'"), NStr("en='any posting status modification';ru='любое изменение состояния проведения'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypePostingDocuments(),
		New Structure(
			"Presentation,Definition,Parameters,ShowToUser",
			Presentation,
			Definition,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddParameter(Val ParameterTable, Val Name, Val Definition, Val DescriptionOfAnyValue)
	
	Parameter = ParameterTable.Add();
	Parameter.Name = Name;
	Parameter.Definition = Definition;
	Parameter.DescriptionOfAnyValue = DescriptionOfAnyValue;
	
EndProcedure

Function ParameterTable()
	
	Result = New ValueTable();
	Result.Columns.Add("Name", New TypeDescription("String"));
	Result.Columns.Add("Definition", New TypeDescription("String"));
	Result.Columns.Add("DescriptionOfAnyValue", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

#EndRegion
