-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- First, update existing enums to include all required values
-- These need to be committed before they can be used

-- Update user_role enum to include all roles
DO $$ 
BEGIN
  -- Check if user_role enum exists and what values it has
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    -- Add missing enum values if they don't exist
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'patient' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE 'patient';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'survivor' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE 'survivor';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'caregiver' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE 'caregiver';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'volunteer' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE 'volunteer';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'ngo' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')) THEN
      ALTER TYPE user_role ADD VALUE 'ngo';
    END IF;
  ELSE
    -- Create the enum if it doesn't exist
    CREATE TYPE user_role AS ENUM ('admin', 'candidate', 'patient', 'survivor', 'caregiver', 'volunteer', 'ngo');
  END IF;
END $$;

-- Create other required enums if they don't exist
DO $$ BEGIN
  CREATE TYPE post_type AS ENUM ('question', 'experience', 'support', 'celebration');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE story_tone AS ENUM ('hopeful', 'inspirational', 'raw', 'grief');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE cancer_type AS ENUM ('breast', 'lung', 'colon', 'blood', 'prostate', 'skin', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE mood_level AS ENUM ('very_low', 'low', 'neutral', 'good', 'very_good');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- COMMIT the enum changes before using them
COMMIT;

-- Start a new transaction for the rest of the migration
BEGIN;

-- Update profiles table to include new columns if they don't exist
-- Add role column with a safe approach
DO $$ 
BEGIN
  -- Add role column if it doesn't exist, using a default that we know exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'role'
  ) THEN
    -- First add the column without a default
    ALTER TABLE public.profiles ADD COLUMN role user_role;
    -- Then set the default value
    ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'patient';
    -- Update existing rows to have the patient role
    UPDATE public.profiles SET role = 'patient' WHERE role IS NULL;
  END IF;
  
  -- Add username column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'username'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN username TEXT UNIQUE;
  END IF;
  
  -- Add age_group column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'age_group'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN age_group TEXT;
  END IF;
  
  -- Add location column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'location'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN location TEXT;
  END IF;
  
  -- Add bio column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'bio'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN bio TEXT;
  END IF;
  
  -- Add cancer_type column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'cancer_type'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN cancer_type cancer_type;
  END IF;
  
  -- Add diagnosis_date column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'diagnosis_date'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN diagnosis_date DATE;
  END IF;
  
  -- Add profile_image_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'profile_image_url'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN profile_image_url TEXT;
  END IF;
  
  -- Add is_anonymous column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'is_anonymous'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN is_anonymous BOOLEAN DEFAULT false;
  END IF;
END $$;

-- Create events table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE,
  location TEXT,
  is_online BOOLEAN DEFAULT false,
  meeting_link TEXT,
  registration_link TEXT,
  max_attendees INTEGER,
  host_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create event_attendees table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.event_attendees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'registered',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Create forum_posts table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.forum_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  post_type post_type DEFAULT 'question',
  is_anonymous BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create stories table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  cancer_type cancer_type,
  tone story_tone DEFAULT 'hopeful',
  age_group TEXT,
  is_anonymous BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create connection_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.connection_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_role user_role,
  age_range TEXT,
  location TEXT,
  message TEXT,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '14 days'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create connection_responses table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.connection_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES public.connection_requests(id) ON DELETE CASCADE,
  responder_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create chat_conversations table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL DEFAULT 'New Chat',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create chat_messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  conversation_id UUID REFERENCES public.chat_conversations(id),
  message TEXT NOT NULL,
  sender TEXT NOT NULL CHECK (sender IN ('user', 'bot')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create donations table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  payment_method TEXT NOT NULL DEFAULT 'paypal',
  transaction_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  donor_name TEXT,
  donor_email TEXT,
  message TEXT,
  is_anonymous BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create community_stats table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.community_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  total_members INTEGER DEFAULT 0,
  total_stories INTEGER DEFAULT 0,
  total_events INTEGER DEFAULT 0,
  total_donations DECIMAL(10,2) DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create private_messages table for user-to-user chat
CREATE TABLE IF NOT EXISTS public.private_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create admin_actions table for audit trail
CREATE TABLE IF NOT EXISTS public.admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Function to update updated_at timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name', 'patient')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin (safe version that handles missing role column)
CREATE OR REPLACE FUNCTION is_admin(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
DECLARE
  user_role_val TEXT;
  column_exists BOOLEAN;
BEGIN
  IF user_id IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Check if role column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'role'
  ) INTO column_exists;
  
  IF NOT column_exists THEN
    RETURN FALSE;
  END IF;
  
  SELECT role::TEXT INTO user_role_val 
  FROM public.profiles 
  WHERE id = user_id;
  
  RETURN COALESCE(user_role_val = 'admin', FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to promote a user to admin (can be called manually)
CREATE OR REPLACE FUNCTION promote_user_to_admin(user_email TEXT)
RETURNS VOID AS $$
DECLARE
  user_count INTEGER;
BEGIN
  UPDATE public.profiles 
  SET role = 'admin'
  WHERE email = user_email;
  
  GET DIAGNOSTICS user_count = ROW_COUNT;
  
  IF user_count = 0 THEN
    RAISE EXCEPTION 'User with email % not found', user_email;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign role to user (admin only)
CREATE OR REPLACE FUNCTION assign_user_role(target_user_id UUID, new_role TEXT)
RETURNS VOID AS $$
DECLARE
  current_user_role_val TEXT;
  user_count INTEGER;
BEGIN
  -- Check if current user is admin
  SELECT role::TEXT INTO current_user_role_val 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF COALESCE(current_user_role_val, '') != 'admin' THEN
    RAISE EXCEPTION 'Only admins can assign roles';
  END IF;
  
  -- Validate the new role
  IF new_role NOT IN ('admin', 'candidate', 'patient', 'survivor', 'caregiver', 'volunteer', 'ngo') THEN
    RAISE EXCEPTION 'Invalid role: %', new_role;
  END IF;
  
  -- Update the target user's role
  UPDATE public.profiles 
  SET role = new_role::user_role, updated_at = NOW()
  WHERE id = target_user_id;
  
  GET DIAGNOSTICS user_count = ROW_COUNT;
  
  IF user_count = 0 THEN
    RAISE EXCEPTION 'User not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connection_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connection_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_actions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and create new ones
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Admin policies for profiles
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles" 
  ON public.profiles 
  FOR SELECT 
  USING (is_admin());

DROP POLICY IF EXISTS "Admins can update any user role" ON public.profiles;
CREATE POLICY "Admins can update any user role" 
  ON public.profiles 
  FOR UPDATE 
  USING (is_admin());

-- Event policies
DROP POLICY IF EXISTS "Anyone can view events" ON public.events;
CREATE POLICY "Anyone can view events" ON public.events FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins and NGOs can create events" ON public.events;
CREATE POLICY "Admins and NGOs can create events" 
  ON public.events 
  FOR INSERT 
  WITH CHECK (
    auth.uid() = host_id AND 
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('admin', 'ngo')
    )
  );

DROP POLICY IF EXISTS "Event hosts and admins can update events" ON public.events;
CREATE POLICY "Event hosts and admins can update events" 
  ON public.events 
  FOR UPDATE 
  USING (
    auth.uid() = host_id OR 
    is_admin()
  );

DROP POLICY IF EXISTS "Event hosts and admins can delete events" ON public.events;
CREATE POLICY "Event hosts and admins can delete events" 
  ON public.events 
  FOR DELETE 
  USING (
    auth.uid() = host_id OR 
    is_admin()
  );

-- Event attendees policies
DROP POLICY IF EXISTS "Anyone can view event attendees" ON public.event_attendees;
CREATE POLICY "Anyone can view event attendees" ON public.event_attendees FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can register for events" ON public.event_attendees;
CREATE POLICY "Authenticated users can register for events" ON public.event_attendees FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own registrations" ON public.event_attendees;
CREATE POLICY "Users can update own registrations" ON public.event_attendees FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can cancel own registrations" ON public.event_attendees;
CREATE POLICY "Users can cancel own registrations" ON public.event_attendees FOR DELETE USING (auth.uid() = user_id);

-- Chat policies
DROP POLICY IF EXISTS "Users can view their own conversations" ON public.chat_conversations;
CREATE POLICY "Users can view their own conversations" 
  ON public.chat_conversations 
  FOR SELECT 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own conversations" ON public.chat_conversations;
CREATE POLICY "Users can create their own conversations" 
  ON public.chat_conversations 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own conversations" ON public.chat_conversations;
CREATE POLICY "Users can update their own conversations" 
  ON public.chat_conversations 
  FOR UPDATE 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own conversations" ON public.chat_conversations;
CREATE POLICY "Users can delete their own conversations" 
  ON public.chat_conversations 
  FOR DELETE 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own chat messages" ON public.chat_messages;
CREATE POLICY "Users can view their own chat messages" 
  ON public.chat_messages 
  FOR SELECT 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own chat messages" ON public.chat_messages;
CREATE POLICY "Users can create their own chat messages" 
  ON public.chat_messages 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Private messages policies
DROP POLICY IF EXISTS "Users can view their own messages" ON public.private_messages;
CREATE POLICY "Users can view their own messages" 
  ON public.private_messages 
  FOR SELECT 
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can send messages" ON public.private_messages;
CREATE POLICY "Users can send messages" 
  ON public.private_messages 
  FOR INSERT 
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Users can update read status of received messages" ON public.private_messages;
CREATE POLICY "Users can update read status of received messages" 
  ON public.private_messages 
  FOR UPDATE 
  USING (auth.uid() = receiver_id);

-- Admin actions policies
DROP POLICY IF EXISTS "Only admins can view admin actions" ON public.admin_actions;
CREATE POLICY "Only admins can view admin actions" 
  ON public.admin_actions 
  FOR SELECT 
  USING (is_admin());

DROP POLICY IF EXISTS "Only admins can create admin actions" ON public.admin_actions;
CREATE POLICY "Only admins can create admin actions" 
  ON public.admin_actions 
  FOR INSERT 
  WITH CHECK (is_admin() AND auth.uid() = admin_id);

-- Community stats policies
DROP POLICY IF EXISTS "Anyone can view community stats" ON public.community_stats;
CREATE POLICY "Anyone can view community stats" 
  ON public.community_stats 
  FOR SELECT 
  USING (true);

-- Donations policies
DROP POLICY IF EXISTS "Users can view their own donations" ON public.donations;
CREATE POLICY "Users can view their own donations" 
  ON public.donations 
  FOR SELECT 
  USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Anyone can create donations" ON public.donations;
CREATE POLICY "Anyone can create donations" 
  ON public.donations 
  FOR INSERT 
  WITH CHECK (true);

-- Connection request policies
DROP POLICY IF EXISTS "Anyone can view active connection requests" ON public.connection_requests;
CREATE POLICY "Anyone can view active connection requests" ON public.connection_requests FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can create requests" ON public.connection_requests;
CREATE POLICY "Authenticated users can create requests" ON public.connection_requests FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- Connection response policies
DROP POLICY IF EXISTS "Request owners can view responses" ON public.connection_responses;
CREATE POLICY "Request owners can view responses" ON public.connection_responses FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.connection_requests WHERE id = request_id AND requester_id = auth.uid())
  OR auth.uid() = responder_id
);

DROP POLICY IF EXISTS "Authenticated users can respond" ON public.connection_responses;
CREATE POLICY "Authenticated users can respond" ON public.connection_responses FOR INSERT WITH CHECK (auth.uid() = responder_id);

-- Create triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at 
  BEFORE UPDATE ON public.profiles 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON public.events;
CREATE TRIGGER update_events_updated_at 
  BEFORE UPDATE ON public.events 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_conversations_updated_at ON public.chat_conversations;
CREATE TRIGGER update_chat_conversations_updated_at 
  BEFORE UPDATE ON public.chat_conversations 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Insert initial community stats if not exists
INSERT INTO public.community_stats (total_members, total_stories, total_events, total_donations)
SELECT 1247, 89, 15, 25430.50
WHERE NOT EXISTS (SELECT 1 FROM public.community_stats);

-- Insert some sample events if events table is empty
INSERT INTO public.events (title, description, start_date, end_date, event_type, is_online, max_attendees)
SELECT 
  'Monthly Support Circle',
  'Join us for emotional support and shared experiences',
  NOW() + INTERVAL '7 days',
  NOW() + INTERVAL '7 days' + INTERVAL '2 hours',
  'Support Group',
  true,
  25
WHERE NOT EXISTS (SELECT 1 FROM public.events);

INSERT INTO public.events (title, description, start_date, end_date, event_type, is_online, max_attendees)
SELECT 
  'Nutrition Workshop',
  'Learn about maintaining health during treatment',
  NOW() + INTERVAL '14 days',
  NOW() + INTERVAL '14 days' + INTERVAL '1.5 hours',
  'Workshop',
  true,
  50
WHERE NOT EXISTS (SELECT 1 FROM public.events WHERE title = 'Nutrition Workshop');

INSERT INTO public.events (title, description, start_date, end_date, event_type, is_online, max_attendees)
SELECT 
  'Wellness Retreat Weekend',
  'A weekend focused on healing and connection',
  NOW() + INTERVAL '30 days',
  NOW() + INTERVAL '32 days',
  'Retreat',
  false,
  30
WHERE NOT EXISTS (SELECT 1 FROM public.events WHERE title = 'Wellness Retreat Weekend');

-- Final commit
COMMIT;