//
//  WebuntisAPI.swift
//  WebuntisExtension
//
//  Created by Christopher Haindl on 15.04.23.
//

import Foundation

class WebUntisAPI: ObservableObject
{
    @Published var currentDate: Date = Date()

    private let baseURLStr = "https://mese.webuntis.com/WebUntis/jsonrpc.do?school=htbla_kaindorf"
    private var sessionID: String = ""
    private var klassenID: Int = 0
    private let school: String = "htbla_kaindorf"

    @Published var displayedDay: Date
    {
        didSet
        {
            if getMondayOfDateInWeek(oldValue) != getMondayOfDateInWeek(displayedDay)
            {
                self.getTimetable()
            }
        }
    }

    @Published var isLoading: Bool = false
    @Published var beginFetchAt: GetTypes? = .login
    @Published var optionsOpen: Bool = false
    @Published var detailedLesson: Lesson? = nil

    @Published var username: String
    {
        didSet
        {
            UserDefaults.standard.set(username, forKey: "username")
        }
    }
    @Published var password: String
    {
        didSet
        {
            UserDefaults.standard.set(password, forKey: "password")
        }
    }

    var klassen: [Klasse] = []
    var rooms: [Room] = []
    var subjects: [Subject] = []
    var departments: [Department] = []
    var holidays: [Holiday] = []
    var schoolYear: SchoolYear = SchoolYear.empty
    var timeGrid: TimeGrid = TimeGrid.empty
    var weekSchedule: [Weekplan] = []

    var mondayOfWeek: Date
    {
        return getMondayOfDateInWeek(self.displayedDay)
    }
    func getMondayOfDateInWeek(_ date: Date) -> Date
    {
        let cl = Calendar.current
        var day = date.withoutTime()
        while cl.component(.weekday, from: day) != 2
        {
            day = cl.date(byAdding: .day, value: -1, to: day)!
        }
        return day
    }

    let dateFormatter = DateFormatter()

    func gettingData()
    {
        switch self.beginFetchAt
        {
        case .login:
            self.login()
            break
        case .subjects:
            self.getSubjects()
            break
        case .klassen:
            self.getKlassen()
            break
        case .rooms:
            self.getRooms()
            break
        case .holidays:
            self.getHolidays()
            break
        case .departments:
            self.getDepartments()
            break
        case .timegridUnits:
            self.getTimegridUnits()
            break
        case .currentSchoolyear:
            self.getCurrentSchoolyear()
            break
        case .timetable:
            self.getTimetable()
            break
        case .none:
            _ = ""
            break
        }
    }
    func errorIn(_ getTypes: GetTypes, httpAnswer: String)
    {
        print(httpAnswer)
        if httpAnswer.contains("not authenticated")
        {
            self.beginFetchAt = .login
        }


        if self.beginFetchAt == nil
        {
            self.beginFetchAt = getTypes
        }
    }

    init() {
        self.username = UserDefaults.standard.string(forKey: "username") ?? ""
        self.password = UserDefaults.standard.string(forKey: "password") ?? ""
        self.displayedDay = Date.now

        dateFormatter.dateFormat = "yyyyMMdd"
        self.gettingData()
    }

    func goBackAWeek()
    {
        let calendar = Calendar.current
        self.displayedDay = calendar.date(byAdding: .weekOfYear, value: -1, to: self.displayedDay)!
    }
    func goForthAWeek()
    {
        let calendar = Calendar.current
        self.displayedDay = calendar.date(byAdding: .weekOfYear, value: 1, to: self.displayedDay)!
    }
    func goToNow()
    {
        self.displayedDay = Date.now
    }

    func getResultOfhttpAnswer(data: Data?) -> String
    {
        guard let data = data else {
            return ""
        }

        var jsonData = String(decoding: data, as: UTF8.self)
        if jsonData.contains("\"result\":")
        {
            jsonData = String(jsonData.split(separator: "\"result\":", maxSplits: 1)[1])
            jsonData = String(jsonData[jsonData.startIndex..<jsonData.index(jsonData.endIndex, offsetBy: -1)])
        }
        return jsonData
    }

    func login() {
        self.sessionID = ""
        let body =
            """
        {
            "id":1,
            "method":"authenticate",
            "params":
                {
                    "user":"\(username)",
                    "password":"\(password)",
                    "client":"\(username)@htl-kaindorf.at"
                },
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            var res = ""
            guard let data = data else {
                self.errorIn(.login, httpAnswer: "")
                return
            }

            res = String(decoding: data, as: UTF8.self)
            if res.contains("sessionId")
            {
//                Get SessionID from JSON part: ..."sessionId":"SESSIONID"...
                self.sessionID = String(String(res.split(separator: "sessionId\":\"", maxSplits: 1)[1]).split(separator: "\"", maxSplits: 1)[0])
                self.klassenID = Int(String(String(res.split(separator: "klasseId\":")[1]).split(separator: "}")[0]))!
                self.getSubjects()
            }
            else
            {
                self.errorIn(.login, httpAnswer: res)
            }
        }.resume()
    }

    func getSubjects()
    {
        let body = """
        {
            "id":"ID",
            "method":"getSubjects",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)

            do
            {
                self.subjects = try JSONDecoder().decode([Subject].self, from: Data(jsonData.utf8))
                self.getKlassen()
            }
            catch
            {
                self.errorIn(.subjects, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getKlassen()
    {
        let body = """
        {
            "id":"ID",
            "method":"getKlassen",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                self.klassen = try JSONDecoder().decode([Klasse].self, from: Data(jsonData.utf8)).filter({ $0.teacher1 != 0 })
                self.getRooms()
            }
            catch
            {
                self.errorIn(.klassen, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getRooms()
    {
        let body = """
        {
            "id":"ID",
            "method":"getRooms",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                self.rooms = try JSONDecoder().decode([Room].self, from: Data(jsonData.utf8))
                self.getHolidays()
            }
            catch
            {
                self.errorIn(.rooms, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getDepartments()
    {
        let body = """
        {
            "id":"ID",
            "method":"getDepartments",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                self.departments = try JSONDecoder().decode([Department].self, from: Data(jsonData.utf8))
                self.getTimegridUnits()
            }
            catch
            {
                self.errorIn(.departments, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getHolidays()
    {
        let body = """
        {
            "id":"ID",
            "method":"getHolidays",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                self.holidays = try JSONDecoder().decode([Holiday].self, from: Data(jsonData.utf8))
                self.getDepartments()
            }
            catch
            {
                self.errorIn(.holidays, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getTimegridUnits()
    {
        let body = """
        {
            "id":"ID",
            "method":"getTimegridUnits",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                var tg = try JSONDecoder().decode([TimeGrid].self, from: Data(jsonData.utf8))[0]
                tg.timeUnits = tg.timeUnits.filter({ $0.startTime >= 800 })
                self.timeGrid = tg
                self.getCurrentSchoolyear()
            }
            catch
            {
                self.errorIn(.timegridUnits, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getCurrentSchoolyear()
    {
        let body = """
        {
            "id":"ID",
            "method":"getCurrentSchoolyear",
            "params":{},
            "jsonrpc":"2.0"
        }
        """

        var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let jsonData = self.getResultOfhttpAnswer(data: data)
            do
            {
                self.schoolYear = try JSONDecoder().decode(SchoolYear.self, from: Data(jsonData.utf8))
                self.getTimetable()
            }
            catch
            {
                self.errorIn(.currentSchoolyear, httpAnswer: jsonData)
            }
        }.resume()
    }

    func getTimetable()
    {
        let oneWeekInSeconds: Int = 604800
        if self.isLoading
        {
            return
        }

        for i in 0..<3
        {
            let monday = self.mondayOfWeek.addingTimeInterval(Double(-oneWeekInSeconds + i * oneWeekInSeconds))
            var inCache = false
            self.weekSchedule.forEach()
            {
                week in
                if self.dateFormatter.string(from: week.mondayOfWeek) == self.dateFormatter.string(from: monday)
                {
                    inCache = true
                    return
                }
            }
            if inCache
            {
                continue
            }
            DispatchQueue.main.async {
                self.isLoading = true
            }
            
            let body = """
            {
                "id":"ID",
                "method":"getTimetable",
                "params":
                    {
                        "id":"\(self.klassenID)",
                        "type":"1",
                        "startDate":\(self.dateFormatter.string(from: monday)),
                        "endDate":\(self.dateFormatter.string(from: monday.addingTimeInterval(Double(432000))))
                    },
                "jsonrpc":"2.0"
            }
            """

            var request = URLRequest(url: URL(string: baseURLStr + "&JSESSIONID=" + self.sessionID)!)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            request.httpBody = body.data(using: .utf8)

            URLSession.shared.dataTask(with: request) { data, _, _ in
                DispatchQueue.main.async {
                    let jsonData = self.getResultOfhttpAnswer(data: data)
                    do
                    {
                        let lesson: [Lesson] = try Lesson.convertTable(webuntisAPI: self, jsonData: jsonData)
                        if self.weekSchedule.count >= 10
                        {
                            self.weekSchedule.remove(at: 0)
                        }
                        self.weekSchedule.append(Weekplan(webuntis: self, lessons: lesson, mondayOfWeek: self.mondayOfWeek.addingTimeInterval(Double(-oneWeekInSeconds + i * oneWeekInSeconds))))
                        self.beginFetchAt = nil
                    }
                    catch
                    {
                        self.errorIn(.timetable, httpAnswer: jsonData)
                    }
                    self.isLoading = false
                }
            }
                .resume()
        }
    }
}
