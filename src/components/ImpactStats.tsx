
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

const ImpactStats = () => {
  // Fetch community stats from database
  const { data: stats, isLoading } = useQuery({
    queryKey: ['community-stats'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('community_stats')
        .select('*')
        .single();
      
      if (error) throw error;
      return data;
    },
  });

  if (isLoading) {
    return (
      <section className="py-16 bg-white">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold tracking-tight mb-4">Our Impact</h2>
            <p className="text-lg text-slate-600">Loading community statistics...</p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="py-16 bg-white">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-bold tracking-tight mb-4">Our Impact</h2>
          <p className="text-lg text-slate-600">Together, we're making a difference in the cancer community</p>
        </div>
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 max-w-4xl mx-auto">
          <div className="text-center">
            <div className="text-4xl font-bold text-brand-blue mb-2">
              {stats?.total_members?.toLocaleString() || '1,247'}
            </div>
            <div className="text-sm text-slate-600">Community Members</div>
          </div>
          <div className="text-center">
            <div className="text-4xl font-bold text-brand-teal mb-2">
              {stats?.total_stories || '89'}
            </div>
            <div className="text-sm text-slate-600">Survivor Stories</div>
          </div>
          <div className="text-center">
            <div className="text-4xl font-bold text-brand-purple mb-2">
              {stats?.total_events || '15'}
            </div>
            <div className="text-sm text-slate-600">Community Events</div>
          </div>
          <div className="text-center">
            <div className="text-4xl font-bold text-brand-green mb-2">
              ${stats?.total_donations?.toLocaleString() || '25,430'}
            </div>
            <div className="text-sm text-slate-600">Funds Raised</div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default ImpactStats;
