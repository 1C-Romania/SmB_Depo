////////////////////////////////////////////////////////////////////////////////
// Subsystem "Personal data protection".
// Service procedures and subsystem functions.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// The function defines the list of events of the event log according to the requirements of the Federal Law No. 152-FZ.
//  
Function ListOfControlledEvents152FL() Export
	
	EventsList = New ValueList;
	EventsList.Add("_$Access$_.Access",					NStr("en='Access. Access';ru='Доступ. Доступ'"));
	EventsList.Add("_$Access$_.AccessDenied",			NStr("en='Access. Access denied';ru='Доступ. Отказ в доступе'"));
	EventsList.Add("_$Session$_.Authentication",		NStr("en='Session. Authentication';ru='Сеанс. Аутентификация'"));
	EventsList.Add("_$Session$_.AuthenticationError",	NStr("en='Session. Authentication error';ru='Сеанс. Ошибка аутентификации'"));
	EventsList.Add("_$Session$_.Start",					NStr("en='Session. Start';ru='Сеанс. Начало'"));
	EventsList.Add("_$Session$_.Finish",				NStr("en='Session. Finish';ru='Сеанс. Завершение'"));
	
	Return EventsList;
	
EndFunction

// The function forms the structure required for setting the image index in the table of the event log.
// 
Function PicturesNumbersOfEvents152FL() Export
	
	PictureNumbers = New Map;
	PictureNumbers.Insert("_$Session$_.Authentication",		1);
	PictureNumbers.Insert("_$Session$_.AuthenticationError",	2);
	PictureNumbers.Insert("_$Session$_.Start",				3);
	PictureNumbers.Insert("_$Session$_.Finish",				4);
	PictureNumbers.Insert("_$Access$_.Access",				5);
	PictureNumbers.Insert("_$Access$_.AccessDenied",			6);
	
	Return PictureNumbers;
	
EndFunction

// The function defines the list of monitored applications of the system
//  according to the requirements of the Federal Law No. 152-FZ.
//
Function ControlledApplicationsList152FL() Export
	
	ApplicationsList = New Array;
	ApplicationsList.Add("1CV8");				// And the 1C:Enterprise application identifier the "Thick client" launch mode; 
	ApplicationsList.Add("1CV8C");				// And the 1C:Enterprise applications identifier the "Thin client" launch mode; 
	ApplicationsList.Add("WebClient");			// And the 1C:Enterprise application identifier the "Web client" launch mode; 
	ApplicationsList.Add("Designer");			// And the Designer application identifier; 

	Return ApplicationsList;
	
EndFunction

#EndRegion
