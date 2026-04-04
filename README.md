# 🏥 Hospital Management System

A comprehensive web-based hospital management system built with Flask and SQL Server. This is a **university project** created as part of database and web development coursework.

> **Note:** This is an educational project. While it implements real-world concepts, it's designed for learning purposes. Suggestions and improvements are always welcome! Feel free to fork, modify, and submit issues or pull requests.

## 📋 Features

- **Patient Management** - Add, update, view patient records
- **Appointment Scheduling** - Schedule and manage patient appointments
- **Billing System** - Track and manage patient billing
- **Doctor Management** - Manage doctor profiles and availability
- **User Authentication** - Secure login system for staff
- **Dashboard** - Overview of hospital operations
- **Responsive Design** - Works on desktop and mobile devices

## 🛠️ Tech Stack

- **Backend:** Python Flask 3.0.3
- **Database:** SQL Server / Azure SQL Database
- **Frontend:** HTML5, CSS3, JavaScript
- **Server:** Gunicorn (production)
- **Deployment:** Azure App Service + Azure SQL

## 📦 Requirements

- Python 3.7+
- SQL Server (local) or Azure SQL Database (production)
- pip (Python package manager)
- Git

## ⚙️ Installation

### 1. Clone the Repository
```bash
git clone https://github.com/viktoryamargaryan/hospital-app.git
cd hospital-app
```

### 2. Create Virtual Environment (Optional but Recommended)
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Create .env File
Create a `.env` file in the project root:

**For Local Development:**
```
FLASK_ENV=development
FLASK_APP=app.py
SECRET_KEY=your-secret-key-here

DATABASE_SERVER=.\SQLEXPRESS
DATABASE_NAME=HospitalDB
DATABASE_USER=
DATABASE_PASSWORD=
```

**For Production (Azure SQL):**
```
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=your-secret-key-here

DATABASE_SERVER=your-server.database.windows.net
DATABASE_NAME=HospitalDB
DATABASE_USER=adminuser@your-server
DATABASE_PASSWORD=YourPassword123!
```

### 5. Set Up Database

#### Option A: Local SQL Server
1. Open SQL Server Management Studio
2. Run the SQL scripts from the `Hospital/` folder in order:
   - `1. Creating_tables.sql`
   - `2. Inserting_data.sql`
   - `3. Queries.sql`
   - `4. Views.sql`
   - `5. Index.sql`
   - `6. Triggers.sql`
   - `7. Stored_procedures.sql`
   - `8. DCL.sql`

#### Option B: Azure SQL Database
1. Create Azure SQL Server and Database
2. Run the same SQL scripts using Azure Data Studio or Management Studio
3. Update .env with Azure credentials

## 🚀 Running the Application

### Development
```bash
python app.py
```
Then open your browser and navigate to: `http://localhost:5000`

### Production (via Gunicorn)
```bash
gunicorn app:app
```

## 🔐 Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

⚠️ **Important:** Change these credentials in production!

## 📁 Project Structure

```
hospital-app/
├── app.py                 # Main Flask application
├── database.py            # Database connection and queries
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables (not in git)
├── .env.example          # Environment template
├── .gitignore            # Git ignore rules
├── README.md             # This file
│
├── routes/               # Route blueprints
│   ├── __init__.py
│   ├── auth.py          # Authentication routes
│   ├── patients.py      # Patient management routes
│   └── hospital.py      # Hospital operations routes
│
├── templates/           # HTML templates
│   ├── login.html       # Login page
│   └── dashboard.html   # Main dashboard
│
└── Hospital/            # SQL database scripts
    ├── 1. Creating_tables.sql
    ├── 2. Inserting_data.sql
    ├── 3. Queries.sql
    ├── 4. Views.sql
    ├── 5. Index.sql
    ├── 6. Triggers.sql
    ├── 7. Stored_procedures.sql
    └── 8. DCL.sql
```
## 🌐 Deployment on Azure

### Prerequisites
- Azure account (azure.microsoft.com)
- GitHub account with code pushed
- Azure SQL Database

### Steps

1. **Create Azure App Service**
   - Go to Azure Portal
   - Click "Create a resource" → Search "App Service"
   - Fill in details:
     - **Resource Group:** Create new
     - **Name:** hospital-app
     - **Runtime stack:** Python 3.11
     - **Region:** Choose closest to you

2. **Connect GitHub Repository**
   - In App Service → Deployment → Deployment Center
   - Select GitHub as source
   - Authorize and select your hospital-app repository
   - Choose main branch

3. **Add Environment Variables**
   - Go to Configuration → Application Settings
   - Add these settings:
   ```
   FLASK_ENV=production
   SECRET_KEY=your-random-secret-key
   DATABASE_SERVER=your-server.database.windows.net
   DATABASE_NAME=HospitalDB
   DATABASE_USER=adminuser@your-server
   DATABASE_PASSWORD=YourPassword123!
   ```

4. **Deploy**
   - Azure automatically deploys when you push to GitHub
   - Check Deployment Center for status
   - Wait 3-5 minutes for deployment
   - Once shows "Success", your app is online!

5. **Access Your App**
   - Your public URL: `https://hospital-app.azurewebsites.net`
   - Login with admin/admin123

## 🔧 Configuration

### Database Configuration
Edit `database.py` to modify database connection settings:
- `SERVER` - SQL Server instance name
- `DATABASE` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password

### Flask Configuration
Edit `app.py` to modify Flask settings:
- `SECRET_KEY` - Session secret (change in production!)
- `FLASK_ENV` - Environment mode (development/production)
- `DEBUG` - Debug mode (always False in production)

## 🐛 Troubleshooting

### "Can't connect to database"
1. Verify .env file has correct credentials
2. Check Azure SQL firewall allows your IP
3. Ensure database server is running
4. For local: Verify SQL Server service is running

### "ModuleNotFoundError"
1. Ensure all dependencies are installed: `pip install -r requirements.txt`
2. Check you're in the correct virtual environment
3. Verify Python 3.7+ is installed

### "CORS errors" or "Can't login"
1. Check CORS configuration in app.py
2. Verify login credentials are correct
3. Clear browser cache and cookies
4. Check browser console for error messages

### Azure Deployment Issues
1. Check Azure App Service logs for error messages
2. Verify environment variables in Configuration → Application Settings
3. Ensure GitHub repository is up to date
4. Restart the App Service from Azure Portal
5. Check Azure SQL firewall allows App Service IP

## 📚 API Routes

### Authentication
- `POST /login` - User login
- `POST /logout` - User logout
- `POST /register` - Create new user

### Patients
- `GET /patients` - List all patients
- `POST /patients` - Add new patient
- `GET /patients/<id>` - Get patient details
- `PUT /patients/<id>` - Update patient
- `DELETE /patients/<id>` - Delete patient

### Appointments
- `GET /appointments` - List appointments
- `POST /appointments` - Schedule appointment
- `PUT /appointments/<id>` - Update appointment
- `DELETE /appointments/<id>` - Cancel appointment

### Billing
- `GET /billing` - View billing records
- `POST /billing` - Create invoice
- `GET /billing/<id>` - Get invoice details

### Hospital
- `GET /dashboard` - Dashboard overview
- `GET /doctors` - List doctors
- `GET /reports` - Hospital reports

## 🎓 University Project Notes

This is an **educational project** created as coursework to demonstrate:
- ✅ Database design and SQL optimization
- ✅ Full-stack web development with Flask
- ✅ RESTful API design
- ✅ Cloud deployment (automatic on Azure)
- ✅ Authentication and security basics
- ✅ HTML/CSS/JavaScript frontend development
- ✅ Git version control

## 💡 Suggestions for Improvement

We'd love to see improvements! 


## 🤝 Contributing

Found a bug or have an idea? We'd love your help!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/YourFeature`)
3. Commit changes (`git commit -m 'Add YourFeature'`)
4. Push to branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

**Before submitting a PR:**
- Test your changes locally
- Update documentation if needed
- Keep code style consistent
- Include a clear description of changes

## 📝 Database Schema

### Tables
- **Users** - Staff login accounts
- **Patients** - Patient information
- **Appointments** - Appointment records
- **Doctors** - Doctor information
- **Billing** - Billing and invoice records
- **Departments** - Hospital departments
- **MedicalRecords** - Patient medical history

See `Hospital/` folder for detailed SQL schema.

## 📄 License

This project is open source and available under the MIT License.

## 👨‍💻 Authors

- **Viktory Margaryan** - Initial development and database design

## 🎯 Future Roadmap

- [ ] Mobile app version (React Native)
- [ ] Advanced reporting and analytics
- [ ] Prescription management system
- [ ] Lab results integration
- [ ] SMS/Email notifications
- [ ] Multi-language support
- [ ] Enhanced role-based access control
- [ ] Payment gateway integration
- [ ] Telemedicine features
- [ ] AI-powered appointment scheduling

## 🎓 Learning Resources Used

- Flask Official Documentation
- SQL Server Tutorial
- Azure Documentation
- Real Python Tutorials
- GitHub Guides

## 📚 References & Inspiration

This project demonstrates real-world concepts from:
- Database normalization and optimization
- RESTful API design principles
- Web application security basics
- Cloud infrastructure management
- Full-stack development workflow

## 🙏 Acknowledgments

- Flask community for the excellent framework
- Microsoft Azure for reliable database hosting
- Stack Overflow community for solutions
- All contributors and users of this project

---

**Project Status:** ✅ Production Ready (Educational Version)
**Last Updated:** April 2026
**Version:** 1.0.0
**Contact:** Feel free to reach out with suggestions!

---

### Quick Links
- 📖 [Documentation](./docs/)
- 🐛 [Report Bug](https://github.com/viktoryamargaryan/hospital-app/issues)
- 💡 [Suggest Feature](https://github.com/viktoryamargaryan/hospital-app/issues)
- 🔗 [Live Demo](https://tinyurl.com/medcore-hospital-center)

**Happy Learning! 🚀**
